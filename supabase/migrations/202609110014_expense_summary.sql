-- Aggregates use the expense's accounting date, not its creation timestamp.
create function public.expense_summary()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare today date := (now() at time zone 'Africa/Casablanca')::date;
  month_start date; month_end date; total bigint; monthly bigint;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  month_start := date_trunc('month',today::timestamp)::date;
  month_end := (month_start + interval '1 month')::date;
  select count(*),coalesce(sum(amount_centimes::bigint),0) into total,monthly
    from public.expenses where voided_at is null and spent_on >= month_start and spent_on < month_end;
  return jsonb_build_object('currency','MAD','clinic_date',today,
    'month_centimes',monthly,'month_transactions',total);
end $$;
revoke all on function public.expense_summary() from public,anon;
grant execute on function public.expense_summary() to authenticated;
