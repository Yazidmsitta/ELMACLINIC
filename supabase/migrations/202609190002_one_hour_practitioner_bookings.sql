create or replace function public.quote_appointment(client uuid, practitioner uuid, service_ids uuid[], slot_start timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare duration integer; amount bigint; items jsonb; slot_end timestamptz;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if service_ids is null or cardinality(service_ids) not between 1 and 10
    or cardinality(service_ids)<>(select count(distinct s) from unnest(service_ids) s)
    or (select count(*) from public.services where id=any(service_ids) and active and deleted_at is null)<>cardinality(service_ids)
    then raise exception 'Sélection de prestations invalide.' using errcode='22023'; end if;
  if not exists(select 1 from public.clients where id=client and deleted_at is null) then raise exception 'Client introuvable.' using errcode='23503'; end if;
  if slot_start is null or not isfinite(slot_start) or slot_start<now() then raise exception 'Choisissez un créneau futur.' using errcode='22023'; end if;
  select sum(price_centimes),jsonb_agg(jsonb_build_object('service_id',id,'name',name,'duration_minutes',duration_minutes,'price_centimes',price_centimes,'quantity',1) order by id)
    into amount,items from public.services where id=any(service_ids);
  duration := 60;
  slot_end := slot_start+make_interval(mins=>duration);
  perform private.check_booking_slot(practitioner,slot_start,slot_end);
  return jsonb_build_object('starts_at',slot_start,'ends_at',slot_end,'duration_minutes',duration,'total_centimes',amount,'services',items);
end $$;

create or replace function public.quote_appointment_cart(client uuid, practitioner uuid, service_ids uuid[], pack_ids uuid[], slot_start timestamptz)
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
  if not exists(select 1 from public.clients where id=client and deleted_at is null) then raise exception 'Client introuvable.' using errcode='23503'; end if;
  select coalesce(sum(s.price_centimes),0)::bigint,
    coalesce(jsonb_agg(jsonb_build_object('service_id',s.id,'name',s.name,'duration_minutes',s.duration_minutes,'price_centimes',s.price_centimes,'quantity',1) order by s.id),'[]'::jsonb)
    into amount,items from public.services s where s.id=any(service_ids);
  select amount + coalesce(sum(p.price_centimes),0)::bigint,
    items || coalesce(jsonb_agg(jsonb_build_object('service_id',null,'name',p.name,'duration_minutes',x.duration_minutes,'price_centimes',p.price_centimes,'quantity',1,'type','PACK') order by p.id),'[]'::jsonb)
    into amount,items
  from public.packs p
  cross join lateral (select coalesce(sum(s.duration_minutes),30)::integer duration_minutes from public.pack_items pi join public.services s on s.id=pi.service_id where pi.pack_id=p.id) x
  where p.id=any(pack_ids);
  if slot_start is null or not isfinite(slot_start) or slot_start<now() then raise exception 'Choisissez un créneau futur.' using errcode='22023'; end if;
  duration := 60;
  slot_end:=slot_start+make_interval(mins=>duration);
  perform private.check_booking_slot(practitioner,slot_start,slot_end);
  return jsonb_build_object('starts_at',slot_start,'ends_at',slot_end,'duration_minutes',duration,'total_centimes',amount,'services',items);
end $$;