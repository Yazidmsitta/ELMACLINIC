-- Payments remain append-only. Refunds/adjustments require a later ledger command.
create function public.record_payment(appointment uuid, amount integer, payment_method text, request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare previous public.payments%rowtype; booking public.appointments%rowtype;
  total bigint; received bigint; result uuid;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if amount is null or amount<=0 or payment_method is null or payment_method not in ('CASH','CARD','TRANSFER') or request_key is null then raise invalid_parameter_value; end if;
  -- Same order as booking commands, preventing concurrent overpayment and archival.
  perform pg_advisory_xact_lock(198413,4);
  select * into previous from public.payments where idempotency_key=request_key;
  if found then
    if previous.recorded_by is distinct from auth.uid() or previous.appointment_id is distinct from appointment
      or previous.amount_centimes<>amount or previous.method<>payment_method then
      raise exception 'Clé de paiement déjà utilisée.' using errcode='23505';
    end if;
    return previous.id;
  end if;
  select * into booking from public.appointments where id=appointment and deleted_at is null for update;
  if not found then return null; end if;
  if booking.status not in ('CONFIRMED','IN_PROGRESS','COMPLETED') then
    raise exception 'Confirmez le rendez-vous avant encaissement.' using errcode='23505';
  end if;
  select coalesce(sum(price_centimes::bigint*quantity),0) into total from public.appointment_services where appointment_id=appointment;
  select coalesce(sum(amount_centimes::bigint),0) into received from public.payments where appointment_id=appointment;
  if amount>total-received then raise exception 'Le montant dépasse le solde du rendez-vous.' using errcode='23505'; end if;
  insert into public.payments(appointment_id,recorded_by,amount_centimes,currency,method,idempotency_key)
    values(appointment,auth.uid(),amount,'MAD',payment_method,request_key) returning id into result;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'RECORD_PAYMENT','payments',result,jsonb_build_object('appointment_id',appointment));
  return result;
end $$;
revoke all on function public.record_payment(uuid,integer,text,uuid) from public,anon;
grant execute on function public.record_payment(uuid,integer,text,uuid) to authenticated;

-- Limited appointment-level operational balance; no clinic totals or staff ledger.
create function public.appointment_payment_balance(appointment uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare total bigint; received bigint;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if not exists(select 1 from public.appointments where id=appointment and deleted_at is null) then return null; end if;
  select coalesce(sum(price_centimes::bigint*quantity),0) into total from public.appointment_services where appointment_id=appointment;
  select coalesce(sum(amount_centimes::bigint),0) into received from public.payments where appointment_id=appointment;
  return jsonb_build_object('appointment_id',appointment,'currency','MAD','total_centimes',total,'paid_centimes',received,'remaining_centimes',total-received);
end $$;
revoke all on function public.appointment_payment_balance(uuid) from public,anon;
grant execute on function public.appointment_payment_balance(uuid) to authenticated;
