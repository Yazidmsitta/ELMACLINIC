alter table public.appointments
  add column if not exists total_override_centimes bigint check(total_override_centimes is null or total_override_centimes >= 0);

create function public.update_appointment_total(record_id uuid, expected_version integer, total_centimes bigint)
returns uuid language plpgsql security definer set search_path='' as $$
declare booking public.appointments%rowtype; received bigint;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if expected_version is null or expected_version <= 0 or total_centimes is null or total_centimes < 0 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into booking from public.appointments where id=record_id and deleted_at is null for update;
  if not found then return null; end if;
  if booking.version is distinct from expected_version then raise exception 'Le rendez-vous a été modifié. Actualisez la fiche.' using errcode='23505'; end if;
  select coalesce(sum(amount_centimes::bigint),0) into received from public.payments where appointment_id=record_id;
  if total_centimes < received then raise exception 'Le total ne peut pas être inférieur aux paiements déjà encaissés.' using errcode='23505'; end if;
  update public.appointments set total_override_centimes=total_centimes,version=version+1 where id=record_id;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'UPDATE_TOTAL','appointments',record_id,jsonb_build_object('total_centimes',total_centimes));
  return record_id;
end $$;
revoke all on function public.update_appointment_total(uuid,integer,bigint) from public,anon;
grant execute on function public.update_appointment_total(uuid,integer,bigint) to authenticated;

create or replace function public.appointment_details(record_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$
  select jsonb_build_object('id',a.id,'client_id',a.client_id,'client_name',c.full_name,'client_phone',c.phone,'practitioner_id',a.practitioner_id,'practitioner_name',p.full_name,'starts_at',a.starts_at,'ends_at',a.ends_at,'status',a.status,'source',a.source,'notes',a.notes,'version',a.version,
    'services',coalesce((select jsonb_agg(jsonb_build_object('service_id',s.service_id,'name',s.service_name,'duration_minutes',s.duration_minutes,'price_centimes',s.price_centimes,'quantity',s.quantity) order by s.id) from public.appointment_services s where s.appointment_id=a.id),'[]'::jsonb),
    'total_centimes',coalesce(a.total_override_centimes,(select sum(s.price_centimes::bigint*s.quantity) from public.appointment_services s where s.appointment_id=a.id),0))
  from public.appointments a join public.clients c on c.id=a.client_id left join public.practitioners p on p.id=a.practitioner_id where a.id=record_id and a.deleted_at is null and private.current_role() is not null
$$;

create or replace function public.record_payment(appointment uuid, amount integer, payment_method text, request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare previous public.payments%rowtype; booking public.appointments%rowtype; total bigint; received bigint; result uuid;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if amount is null or amount<=0 or payment_method is null or payment_method not in ('CASH','CARD','TRANSFER') or request_key is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into previous from public.payments where idempotency_key=request_key;
  if found then
    if previous.recorded_by is distinct from auth.uid() or previous.appointment_id is distinct from appointment or previous.amount_centimes<>amount or previous.method<>payment_method then raise exception 'Clé de paiement déjà utilisée.' using errcode='23505'; end if;
    return previous.id;
  end if;
  select * into booking from public.appointments where id=appointment and deleted_at is null for update;
  if not found then return null; end if;
  if booking.status not in ('CONFIRMED','IN_PROGRESS','COMPLETED') then raise exception 'Confirmez le rendez-vous avant encaissement.' using errcode='23505'; end if;
  select coalesce(booking.total_override_centimes,coalesce(sum(s.price_centimes::bigint*s.quantity),0)) into total from public.appointment_services s where s.appointment_id=appointment;
  select coalesce(sum(amount_centimes::bigint),0) into received from public.payments where appointment_id=appointment;
  if amount>total-received then raise exception 'Le montant dépasse le solde du rendez-vous.' using errcode='23505'; end if;
  insert into public.payments(appointment_id,recorded_by,amount_centimes,currency,method,idempotency_key) values(appointment,auth.uid(),amount,'MAD',payment_method,request_key) returning id into result;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'RECORD_PAYMENT','payments',result,jsonb_build_object('appointment_id',appointment));
  return result;
end $$;

create or replace function public.appointment_payment_balance(appointment uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare total bigint; received bigint; override_total bigint;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if not exists(select 1 from public.appointments where id=appointment and deleted_at is null) then return null; end if;
  select a.total_override_centimes into override_total from public.appointments a where a.id=appointment;
  select coalesce(override_total,coalesce(sum(price_centimes::bigint*quantity),0)) into total from public.appointment_services where appointment_id=appointment;
  select coalesce(sum(amount_centimes::bigint),0) into received from public.payments where appointment_id=appointment;
  return jsonb_build_object('appointment_id',appointment,'currency','MAD','total_centimes',total,'paid_centimes',received,'remaining_centimes',total-received);
end $$;