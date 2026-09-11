-- Durable receipt/review queue. Only the verified server adapter may enqueue.
create table public.website_booking_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check(provider='elmaclinic.ma'),
  event_id text not null check(length(event_id) between 1 and 200),
  booking_id text not null check(length(booking_id) between 1 and 200),
  payload jsonb not null check(jsonb_typeof(payload)='object'),
  occurred_at timestamptz not null check(isfinite(occurred_at)),
  state text not null default 'REVIEW' check(state in ('REVIEW','IMPORTED','DISMISSED')),
  version integer not null default 1 check(version>0),
  appointment_id uuid references public.appointments(id),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(provider,event_id)
);
alter table public.website_booking_events enable row level security;
revoke all on public.website_booking_events from anon,authenticated;
grant select on public.website_booking_events to authenticated;
create policy staff_read on public.website_booking_events for select to authenticated
  using(private.current_role() is not null);
create trigger touch_updated_at before update on public.website_booking_events
  for each row execute function private.touch_updated_at();
create index website_events_review_idx on public.website_booking_events(state,created_at,id);
create index website_events_booking_idx on public.website_booking_events(provider,booking_id,occurred_at);

create function public.receive_website_booking(event_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare previous public.website_booking_events%rowtype; result uuid;
begin
  -- Execute grant is service_role only. Caller must use the signed adapter.
  if event_payload is null or jsonb_typeof(event_payload)<>'object'
    or event_payload->>'provider' is distinct from 'elmaclinic.ma'
    or event_payload->>'source' is distinct from 'WEBSITE'
    or coalesce(length(event_payload->>'event_id'),0) not between 1 and 200
    or coalesce(length(event_payload->>'booking_id'),0) not between 1 and 200
    or event_payload->>'occurred_at' is null
    or not isfinite((event_payload->>'occurred_at')::timestamptz)
    or octet_length(event_payload::text)>65536 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into previous from public.website_booking_events
    where provider='elmaclinic.ma' and event_id=event_payload->>'event_id';
  if found then
    if previous.payload<>event_payload then
      raise exception 'Identifiant d’événement déjà utilisé.' using errcode='23505';
    end if;
    return jsonb_build_object('id',previous.id,'state',previous.state,'appointment_id',previous.appointment_id,'replayed',true);
  end if;
  insert into public.website_booking_events(provider,event_id,booking_id,payload,occurred_at)
    values('elmaclinic.ma',event_payload->>'event_id',event_payload->>'booking_id',event_payload,(event_payload->>'occurred_at')::timestamptz)
    returning id into result;
  insert into public.activity_logs(action,entity_type,entity_id)
    values('RECEIVE','website_booking_events',result);
  return jsonb_build_object('id',result,'state','REVIEW','appointment_id',null,'replayed',false);
end $$;
revoke all on function public.receive_website_booking(jsonb) from public,anon,authenticated;
grant execute on function public.receive_website_booking(jsonb) to service_role;

-- Explicit staff resolution; never guesses catalog identities from names.
create function public.import_website_booking(event_record uuid, expected_version integer,
  client uuid, practitioner uuid, service_ids uuid[], expected_total bigint, expected_duration integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare incoming public.website_booking_events%rowtype; quote jsonb; result uuid; slot_start timestamptz;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into incoming from public.website_booking_events where id=event_record for update;
  if not found then return null; end if;
  if incoming.version is distinct from expected_version or incoming.state<>'REVIEW' then
    raise exception 'Réservation modifiée. Actualisez la fiche.' using errcode='23505';
  end if;
  if exists(select 1 from public.appointments where external_provider=incoming.provider and external_id=incoming.booking_id)
    or exists(select 1 from public.website_booking_events where provider=incoming.provider and booking_id=incoming.booking_id
      and id<>incoming.id and occurred_at>=incoming.occurred_at) then
    raise exception 'Réservation existante ou événement plus récent à vérifier.' using errcode='23505';
  end if;
  slot_start := (incoming.payload->>'starts_at')::timestamptz;
  if slot_start is null or length(coalesce(incoming.payload->>'notes',''))>2000 then raise invalid_parameter_value; end if;
  perform 1 from public.clients where id=client for share;
  perform 1 from public.practitioners where id=practitioner for update;
  perform 1 from public.services where id=any(service_ids) order by id for share;
  quote := public.quote_appointment(client,practitioner,service_ids,slot_start);
  if expected_total is distinct from (quote->>'total_centimes')::bigint
    or expected_duration is distinct from (quote->>'duration_minutes')::integer then
    raise exception 'Le tarif ou la durée a changé. Vérifiez le nouveau devis.' using errcode='23505';
  end if;
  insert into public.appointments(client_id,practitioner_id,starts_at,ends_at,source,status,created_by,notes,external_provider,external_id,external_updated_at)
    values(client,practitioner,slot_start,(quote->>'ends_at')::timestamptz,'WEBSITE','NEW',auth.uid(),incoming.payload->>'notes',incoming.provider,incoming.booking_id,incoming.occurred_at)
    returning id into result;
  insert into public.appointment_services(appointment_id,service_id,service_name,duration_minutes,price_centimes)
    select result,id,name,duration_minutes,price_centimes from public.services where id=any(service_ids);
  update public.website_booking_events set state='IMPORTED',appointment_id=result,reviewed_by=auth.uid(),reviewed_at=now(),version=version+1 where id=event_record;
  insert into public.notifications(recipient_id,type,appointment_id,event_key,payload)
    select id,'WEBSITE_BOOKING',result,'website:'||event_record::text,jsonb_build_object('source','WEBSITE')
    from public.profiles where active on conflict(recipient_id,event_key) do nothing;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'IMPORT','appointments',result,jsonb_build_object('event_id',event_record));
  return result;
end $$;
revoke all on function public.import_website_booking(uuid,integer,uuid,uuid,uuid[],bigint,integer) from public,anon;
grant execute on function public.import_website_booking(uuid,integer,uuid,uuid,uuid[],bigint,integer) to authenticated;
