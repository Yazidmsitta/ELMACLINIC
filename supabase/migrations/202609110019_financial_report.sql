create function public.financial_report(first_day date,last_day date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare received bigint; spent bigint; receipts bigint; expenses bigint;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if first_day is null or last_day is null or not isfinite(first_day) or not isfinite(last_day)
    or last_day<first_day or last_day-first_day>366 then raise invalid_parameter_value; end if;
  select coalesce(sum(amount_centimes::bigint),0),count(*) into received,receipts from public.payments
    where paid_at>=first_day::timestamp at time zone 'Africa/Casablanca'
      and paid_at<(last_day+1)::timestamp at time zone 'Africa/Casablanca';
  select coalesce(sum(amount_centimes::bigint),0),count(*) into spent,expenses from public.expenses
    where voided_at is null and spent_on between first_day and last_day;
  return jsonb_build_object('currency','MAD','from',first_day,'to',last_day,
    'received_centimes',received,'expense_centimes',spent,'cash_balance_centimes',received-spent,
    'receipt_count',receipts,'expense_count',expenses);
end $$;
revoke all on function public.financial_report(date,date) from public,anon;
grant execute on function public.financial_report(date,date) to authenticated;
