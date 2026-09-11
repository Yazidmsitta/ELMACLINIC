create function public.payment_ledger(page_number integer default 1)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare today date := (now() at time zone 'Africa/Casablanca')::date;
  day_start timestamptz; day_end timestamptz; month_start timestamptz; month_end timestamptz;
  result jsonb; total bigint; daily bigint; monthly bigint;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if page_number is null or page_number not between 1 and 100000 then raise invalid_parameter_value; end if;
  day_start:=today::timestamp at time zone 'Africa/Casablanca';
  day_end:=(today+1)::timestamp at time zone 'Africa/Casablanca';
  month_start:=date_trunc('month',today::timestamp) at time zone 'Africa/Casablanca';
  month_end:=(date_trunc('month',today::timestamp)+interval '1 month') at time zone 'Africa/Casablanca';
  select count(*),coalesce(sum(amount_centimes::bigint) filter(where paid_at>=day_start and paid_at<day_end),0),
    coalesce(sum(amount_centimes::bigint) filter(where paid_at>=month_start and paid_at<month_end),0)
    into total,daily,monthly from public.payments;
  select coalesce(jsonb_agg(row order by row.paid_at desc,row.id),'[]'::jsonb) into result from (
    select p.id,p.appointment_id,p.amount_centimes,p.currency,p.method,p.paid_at,c.full_name as client_name,
      coalesce((select string_agg(s.service_name,', ' order by s.id) from public.appointment_services s where s.appointment_id=a.id),'') as service_names
    from public.payments p join public.appointments a on a.id=p.appointment_id join public.clients c on c.id=a.client_id
    order by p.paid_at desc,p.id limit 50 offset (page_number-1)*50
  ) row;
  return jsonb_build_object('data',result,'total',total,'page',page_number,'per_page',50,'has_more',page_number*50<total,
    'currency','MAD','clinic_date',today,'today_centimes',daily,'month_centimes',monthly);
end $$;
revoke all on function public.payment_ledger(integer) from public,anon;
grant execute on function public.payment_ledger(integer) to authenticated;
