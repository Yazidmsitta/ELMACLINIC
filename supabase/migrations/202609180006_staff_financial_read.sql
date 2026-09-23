create or replace function public.dashboard_summary() returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
 staff_role text := private.current_role();
 clinic_day date := (now() at time zone 'Africa/Casablanca')::date;
 day_start timestamptz;
 day_end timestamptz;
 summary jsonb;
begin
 if staff_role is null then raise insufficient_privilege; end if;
 day_start := clinic_day::timestamp at time zone 'Africa/Casablanca';
 day_end := (clinic_day+1)::timestamp at time zone 'Africa/Casablanca';
 summary := jsonb_build_object(
  'date',clinic_day,
  'appointments_today',(select count(*) from public.appointments where deleted_at is null and starts_at>=day_start and starts_at<day_end),
  'clients_total',(select count(*) from public.clients where deleted_at is null),
  'pending',(select count(*) from public.appointments where deleted_at is null and status in ('NEW','PENDING','CONFIRMED','IN_PROGRESS') and starts_at>now()),
  'website_new',(select count(*) from public.appointments where deleted_at is null and source='WEBSITE' and status='NEW'),
  'revenue_today_centimes',coalesce((select sum(amount_centimes) from public.payments where paid_at>=day_start and paid_at<day_end),0),
  'week_revenue',(select jsonb_agg(jsonb_build_object('date',d::date,'amount_centimes',coalesce((select sum(p.amount_centimes) from public.payments p where (p.paid_at at time zone 'Africa/Casablanca')::date=d::date),0)) order by d) from generate_series(date_trunc('week',clinic_day::timestamp),date_trunc('week',clinic_day::timestamp)+interval '6 days',interval '1 day') d),
  'schedule',coalesce((select jsonb_agg(row_to_json(a)) from (
   select a.id, to_char(a.starts_at at time zone 'Africa/Casablanca','HH24:MI') as time,
    (extract(epoch from a.ends_at-a.starts_at)/60)::integer as duration,
    c.full_name as client_name, coalesce((select string_agg(s.service_name,', ' order by s.created_at) from public.appointment_services s where s.appointment_id=a.id),'Prestation à préciser') as service_name,
    a.status,a.source
   from public.appointments a join public.clients c on c.id=a.client_id
   where a.deleted_at is null and a.starts_at>=day_start and a.starts_at<day_end order by a.starts_at,a.id limit 4
  ) a),'[]'::jsonb),
  'notifications',coalesce((select jsonb_agg(row_to_json(n)) from (
   select id,type,read_at,created_at from public.notifications where recipient_id=auth.uid() order by created_at desc limit 20
  ) n),'[]'::jsonb)
 );
 return summary;
end $$;

create or replace function public.payment_ledger(page_number integer default 1)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare today date := (now() at time zone 'Africa/Casablanca')::date;
  day_start timestamptz; day_end timestamptz; month_start timestamptz; month_end timestamptz;
  result jsonb; total bigint; daily bigint; monthly bigint;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if page_number is null or page_number not between 1 and 100000 then raise invalid_parameter_value; end if;
  day_start:=today::timestamp at time zone 'Africa/Casablanca';
  day_end:=(today+1)::timestamp at time zone 'Africa/Casablanca';
  month_start:=date_trunc('month',today::timestamp) at time zone 'Africa/Casablanca';
  month_end:=(date_trunc('month',today::timestamp)+interval '1 month') at time zone 'Africa/Casablanca';
  select count(*),coalesce(sum(amount_centimes::bigint) filter(where paid_at>=day_start and paid_at<day_end),0),
    coalesce(sum(amount_centimes::bigint) filter(where paid_at>=month_start and paid_at<month_end),0)
    into total,daily,monthly from public.payments;
  select coalesce(jsonb_agg(row order by row.paid_at desc,row.id),'[]'::jsonb) into result from (
    select p.id,p.appointment_id,p.amount_centimes,p.currency,p.method,p.paid_at,
      c.id as client_id,c.full_name as client_name,
      greatest(
        coalesce((select sum(coalesce((select sum(s.price_centimes::bigint*s.quantity) from public.appointment_services s where s.appointment_id=a.id),0))
          from public.appointments a
          where a.client_id=c.id and a.deleted_at is null and a.status in ('CONFIRMED','IN_PROGRESS','COMPLETED')),0)
        - coalesce((select sum(paid.amount_centimes::bigint) from public.payments paid
          join public.appointments paid_a on paid_a.id=paid.appointment_id
          where paid_a.client_id=c.id),0),
        0
      )::integer as remaining_centimes,
      coalesce((select string_agg(s.service_name,', ' order by s.id) from public.appointment_services s where s.appointment_id=a.id),'') as service_names
    from public.payments p join public.appointments a on a.id=p.appointment_id join public.clients c on c.id=a.client_id
    order by p.paid_at desc,p.id limit 50 offset (page_number-1)*50
  ) row;
  return jsonb_build_object('data',result,'total',total,'page',page_number,'per_page',50,'has_more',page_number*50<total,
    'currency','MAD','clinic_date',today,'today_centimes',daily,'month_centimes',monthly);
end $$;
