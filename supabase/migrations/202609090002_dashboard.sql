-- Invoker privileges preserve table RLS. Financial keys do not exist for USER.
create function public.dashboard_summary() returns jsonb language plpgsql stable security invoker set search_path = '' as $$
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
  'pending',(select count(*) from public.appointments where deleted_at is null and status='PENDING' and starts_at>=day_start and starts_at<day_end),
  'website_new',(select count(*) from public.appointments where deleted_at is null and source='WEBSITE' and status='NEW'),
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
 if staff_role='ADMIN' then
  summary := summary || jsonb_build_object(
   'revenue_today_centimes',coalesce((select sum(amount_centimes) from public.payments where paid_at>=day_start and paid_at<day_end),0),
   'week_revenue', (select jsonb_agg(jsonb_build_object('date',d::date,'amount_centimes',coalesce((select sum(p.amount_centimes) from public.payments p where (p.paid_at at time zone 'Africa/Casablanca')::date=d::date),0)) order by d) from generate_series(date_trunc('week',clinic_day::timestamp),date_trunc('week',clinic_day::timestamp)+interval '6 days',interval '1 day') d)
  );
 end if;
 return summary;
end $$;
revoke all on function public.dashboard_summary() from public,anon;
grant execute on function public.dashboard_summary() to authenticated;
