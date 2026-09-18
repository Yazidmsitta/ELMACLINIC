alter table public.appointment_services
  add column if not exists pack_id uuid references public.packs(id);

create index if not exists appointment_services_pack_idx
  on public.appointment_services(pack_id);

create or replace function public.quote_appointment_cart(
  client uuid, practitioner uuid, service_ids uuid[], pack_ids uuid[], slot_start timestamptz
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare duration integer; amount bigint; items jsonb; slot_end timestamptz;
begin
  if private.current_role() is null or service_ids is null or pack_ids is null
    or (cardinality(service_ids)=0 and cardinality(pack_ids)=0)
    or cardinality(service_ids)>10 or cardinality(pack_ids)>10
    or exists(select 1 from public.services where id=any(service_ids) and (not active or deleted_at is not null))
    or exists(select 1 from public.packs where id=any(pack_ids) and not active) then
    raise exception 'Sélection de prestations invalide.' using errcode='22023';
  end if;
  if not exists(select 1 from public.clients where id=client and deleted_at is null) then
    raise exception 'Client introuvable.' using errcode='23503';
  end if;
  select coalesce(sum(s.duration_minutes),0)::integer, coalesce(sum(s.price_centimes),0)::bigint,
    coalesce(jsonb_agg(jsonb_build_object('service_id',s.id,'name',s.name,'duration_minutes',s.duration_minutes,'price_centimes',s.price_centimes,'quantity',1) order by s.id),'[]'::jsonb)
    into duration,amount,items from public.services s where s.id=any(service_ids);
  select duration + coalesce(sum(x.duration_minutes),0)::integer,
    amount + coalesce(sum(p.price_centimes),0)::bigint,
    items || coalesce(jsonb_agg(jsonb_build_object('service_id',null,'name',p.name,'duration_minutes',x.duration_minutes,'price_centimes',p.price_centimes,'quantity',1,'type','PACK') order by p.id),'[]'::jsonb)
    into duration,amount,items
  from public.packs p
  cross join lateral (select coalesce(sum(s.duration_minutes),30)::integer duration_minutes from public.pack_items pi join public.services s on s.id=pi.service_id where pi.pack_id=p.id) x
  where p.id=any(pack_ids);
  if slot_start is null or not isfinite(slot_start) or slot_start<now() then raise exception 'Choisissez un créneau futur.' using errcode='22023'; end if;
  slot_end:=slot_start+make_interval(mins=>duration);
  perform private.check_booking_slot(practitioner,slot_start,slot_end);
  return jsonb_build_object('starts_at',slot_start,'ends_at',slot_end,'duration_minutes',duration,'total_centimes',amount,'services',items);
end $$;
revoke all on function public.quote_appointment_cart(uuid,uuid,uuid[],uuid[],timestamptz) from public,anon;
grant execute on function public.quote_appointment_cart(uuid,uuid,uuid[],uuid[],timestamptz) to authenticated;

create or replace function public.create_manual_appointment_cart(
  client uuid, practitioner uuid, service_ids uuid[], pack_ids uuid[], slot_start timestamptz,
  booking_notes text, request_key uuid, expected_total bigint, expected_duration integer
)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; quote jsonb; payload jsonb; previous private.booking_requests%rowtype;
begin
  if private.current_role() is null or request_key is null or length(coalesce(booking_notes,''))>2000 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  payload:=jsonb_build_object('client',client,'practitioner',practitioner,'services',service_ids,'packs',pack_ids,'starts_at',slot_start,'notes',booking_notes,'expected_total',expected_total,'expected_duration',expected_duration);
  select * into previous from private.booking_requests where actor_id=auth.uid() and request_id=request_key;
  if found then if previous.payload<>payload then raise exception 'Clé de requête déjà utilisée.' using errcode='23505'; end if; return previous.appointment_id; end if;
  quote:=public.quote_appointment_cart(client,practitioner,service_ids,pack_ids,slot_start);
  if expected_total is distinct from (quote->>'total_centimes')::bigint or expected_duration is distinct from (quote->>'duration_minutes')::integer then raise exception 'Le tarif ou la durée a changé. Vérifiez le nouveau devis.' using errcode='23505'; end if;
  insert into public.appointments(client_id,practitioner_id,starts_at,ends_at,source,status,created_by,notes)
    values(client,practitioner,slot_start,(quote->>'ends_at')::timestamptz,'MANUAL','CONFIRMED',auth.uid(),booking_notes) returning id into result;
  insert into public.appointment_services(appointment_id,service_id,service_name,duration_minutes,price_centimes)
    select result,s.id,s.name,s.duration_minutes,s.price_centimes from public.services s where s.id=any(service_ids);
  insert into public.appointment_services(appointment_id,service_id,service_name,duration_minutes,price_centimes,pack_id)
    select result,pi.service_id,p.name,s.duration_minutes,p.price_centimes,p.id
    from public.packs p join public.pack_items pi on pi.pack_id=p.id join public.services s on s.id=pi.service_id
    where p.id=any(pack_ids);
  insert into private.booking_requests values(auth.uid(),request_key,payload,result);
  insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'CREATE','appointments',result);
  return result;
end $$;
revoke all on function public.create_manual_appointment_cart(uuid,uuid,uuid[],uuid[],timestamptz,text,uuid,bigint,integer) from public,anon;
grant execute on function public.create_manual_appointment_cart(uuid,uuid,uuid[],uuid[],timestamptz,text,uuid,bigint,integer) to authenticated;

create or replace function public.client_profile(record_id uuid)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare
  client_row jsonb;
  today_rows jsonb;
  history_rows jsonb;
  pack_rows jsonb;
  day_start timestamptz := (now() at time zone 'Africa/Casablanca')::date::timestamp at time zone 'Africa/Casablanca';
  day_end timestamptz := (((now() at time zone 'Africa/Casablanca')::date + 1)::timestamp at time zone 'Africa/Casablanca');
begin
  if private.current_role() is null then raise insufficient_privilege; end if;

  select jsonb_build_object(
    'id',c.id,
    'full_name',c.full_name,
    'phone',c.phone,
    'email',c.email,
    'birth_date',c.birth_date,
    'created_at',c.created_at
  ) into client_row
  from public.clients c
  where c.id=record_id and c.deleted_at is null;

  if client_row is null then return null; end if;

  select coalesce(jsonb_agg(public.appointment_details(a.id) order by a.starts_at,a.id),'[]'::jsonb) into today_rows
  from public.appointments a
  where a.client_id=record_id and a.deleted_at is null and a.starts_at>=day_start and a.starts_at<day_end;

  select coalesce(jsonb_agg(public.appointment_details(id) order by starts_at desc,id desc),'[]'::jsonb) into history_rows
  from (
    select a.id,a.starts_at from public.appointments a
    where a.client_id=record_id and a.deleted_at is null
    order by a.starts_at desc,a.id desc
    limit 50
  ) recent;

  with pack_purchases as (
    select
      aps.pack_id,
      max(p.name) as name,
      sum(coalesce(p.total_sessions,1))::integer as purchased_sessions,
      count(distinct a.id) filter (where a.status='COMPLETED')::integer as appointment_completed_sessions
    from public.appointment_services aps
    join public.appointments a on a.id=aps.appointment_id
    join public.packs p on p.id=aps.pack_id
    where a.client_id=record_id and a.deleted_at is null and aps.pack_id is not null
    group by aps.pack_id
  ), pack_usage as (
    select
      pp.pack_id,
      pp.name,
      pp.purchased_sessions::integer as total_sessions,
      least(pp.purchased_sessions, greatest(pp.appointment_completed_sessions + coalesce((
        select sum(adj.delta) from public.client_pack_session_adjustments adj
        where adj.client_id=record_id and adj.pack_id=pp.pack_id
      ),0),0))::integer as completed_sessions
    from pack_purchases pp
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'pack_id',pack_id,
    'name',name,
    'total_sessions',total_sessions,
    'completed_sessions',least(completed_sessions,total_sessions),
    'remaining_sessions',greatest(total_sessions-completed_sessions,0),
    'status',case when greatest(total_sessions-completed_sessions,0)=0 then 'COMPLET' else 'EN_ATTENTE' end
  ) order by name,pack_id),'[]'::jsonb) into pack_rows
  from pack_usage;

  return jsonb_build_object(
    'client',client_row,
    'today',today_rows,
    'history',history_rows,
    'packs',pack_rows
  );
end $$;
revoke all on function public.client_profile(uuid) from public,anon;
grant execute on function public.client_profile(uuid) to authenticated;
