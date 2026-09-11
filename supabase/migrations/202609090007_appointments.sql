alter table public.appointments add column version integer not null default 1 check(version>0);
create table private.booking_requests (
  actor_id uuid not null references public.profiles(id), request_id uuid not null,
  payload jsonb not null, appointment_id uuid not null references public.appointments(id),
  primary key(actor_id,request_id)
);

create function private.check_booking_slot(practitioner uuid, slot_start timestamptz, slot_end timestamptz, excluded uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare local_start timestamp := slot_start at time zone 'Africa/Casablanca';
  local_end timestamp := slot_end at time zone 'Africa/Casablanca';
begin
  if slot_start is null or slot_end is null or not isfinite(slot_start) or not isfinite(slot_end) or slot_end<=slot_start then raise invalid_parameter_value; end if;
  if not exists(select 1 from public.practitioners where id=practitioner and active and deleted_at is null) then
    raise exception 'Praticienne inactive ou introuvable.' using errcode='23503'; end if;
  if local_start::date<>local_end::date or not exists(
    select 1 from public.practitioner_schedules where practitioner_id=practitioner
      and weekday=extract(isodow from local_start) and starts_at<=local_start::time and ends_at>=local_end::time
  ) then raise exception 'Le rendez-vous doit être compris dans un créneau de travail.' using errcode='23P01'; end if;
  if exists(select 1 from public.practitioner_time_off where practitioner_id=practitioner and starts_at<slot_end and ends_at>slot_start)
    then raise exception 'La praticienne est absente sur ce créneau.' using errcode='23P01'; end if;
  if exists(select 1 from public.appointments where practitioner_id=practitioner and deleted_at is null
    and status in ('NEW','PENDING','CONFIRMED','IN_PROGRESS') and id is distinct from excluded
    and starts_at<slot_end and ends_at>slot_start)
    then raise exception 'Ce créneau est déjà réservé.' using errcode='23P01'; end if;
end $$;
revoke all on function private.check_booking_slot(uuid,timestamptz,timestamptz,uuid) from public,anon,authenticated;

create function public.quote_appointment(client uuid, practitioner uuid, service_ids uuid[], slot_start timestamptz)
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
  select sum(duration_minutes),sum(price_centimes),jsonb_agg(jsonb_build_object('service_id',id,'name',name,'duration_minutes',duration_minutes,'price_centimes',price_centimes,'quantity',1) order by id)
    into duration,amount,items from public.services where id=any(service_ids);
  if duration>1440 then raise invalid_parameter_value; end if;
  slot_end := slot_start+make_interval(mins=>duration);
  perform private.check_booking_slot(practitioner,slot_start,slot_end);
  return jsonb_build_object('starts_at',slot_start,'ends_at',slot_end,'duration_minutes',duration,'total_centimes',amount,'services',items);
end $$;
revoke all on function public.quote_appointment(uuid,uuid,uuid[],timestamptz) from public,anon;
grant execute on function public.quote_appointment(uuid,uuid,uuid[],timestamptz) to authenticated;

create function public.create_manual_appointment(client uuid, practitioner uuid, service_ids uuid[], slot_start timestamptz, booking_notes text, request_key uuid, expected_total bigint, expected_duration integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; quote jsonb; payload jsonb; previous private.booking_requests%rowtype;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if request_key is null or length(coalesce(booking_notes,''))>2000 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  payload := jsonb_build_object('client',client,'practitioner',practitioner,'services',service_ids,'starts_at',slot_start,'notes',booking_notes,'expected_total',expected_total,'expected_duration',expected_duration);
  select * into previous from private.booking_requests where actor_id=auth.uid() and request_id=request_key;
  if found then
    if previous.payload<>payload then raise exception 'Clé de requête déjà utilisée.' using errcode='23505'; end if;
    return previous.appointment_id;
  end if;
  -- Shared catalog/client locks keep the quote stable through snapshot creation.
  perform 1 from public.clients where id=client for share;
  perform 1 from public.practitioners where id=practitioner for update;
  perform 1 from public.services where id=any(service_ids) order by id for share;
  quote := public.quote_appointment(client,practitioner,service_ids,slot_start);
  if expected_total is distinct from (quote->>'total_centimes')::bigint or expected_duration is distinct from (quote->>'duration_minutes')::integer then raise exception 'Le tarif ou la durée a changé. Vérifiez le nouveau devis.' using errcode='23505'; end if;
  insert into public.appointments(client_id,practitioner_id,starts_at,ends_at,source,status,created_by,notes)
    values(client,practitioner,slot_start,(quote->>'ends_at')::timestamptz,'MANUAL','CONFIRMED',auth.uid(),booking_notes) returning id into result;
  insert into public.appointment_services(appointment_id,service_id,service_name,duration_minutes,price_centimes)
    select result,id,name,duration_minutes,price_centimes from public.services where id=any(service_ids);
  insert into private.booking_requests values(auth.uid(),request_key,payload,result);
  insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'CREATE','appointments',result);
  return result;
end $$;
revoke all on function public.create_manual_appointment(uuid,uuid,uuid[],timestamptz,text,uuid,bigint,integer) from public,anon;
grant execute on function public.create_manual_appointment(uuid,uuid,uuid[],timestamptz,text,uuid,bigint,integer) to authenticated;

create function public.change_appointment(record_id uuid, expected_version integer, command text, new_practitioner uuid default null, new_start timestamptz default null, new_notes text default null, new_status text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare original public.appointments%rowtype; target_end timestamptz;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if command='ARCHIVE' and private.current_role()<>'ADMIN' then raise insufficient_privilege; end if;
  if command not in ('RESCHEDULE','STATUS','ARCHIVE') or command is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into original from public.appointments where id=record_id and deleted_at is null;
  if not found then return null; end if;
  if expected_version is distinct from original.version then raise exception 'Le rendez-vous a été modifié. Actualisez la fiche.' using errcode='23505'; end if;
  perform 1 from public.practitioners where id in (original.practitioner_id,new_practitioner) order by id for update;
  if command='ARCHIVE' then
    update public.appointments set deleted_at=now(),version=version+1 where id=record_id;
  elsif command='RESCHEDULE' then
    if original.status not in ('NEW','PENDING','CONFIRMED') then raise exception 'Ce rendez-vous ne peut plus être déplacé.' using errcode='23505'; end if;
    if new_start is null or new_start<now() or length(coalesce(new_notes,''))>2000 then raise invalid_parameter_value; end if;
    target_end := new_start+(original.ends_at-original.starts_at);
    perform private.check_booking_slot(new_practitioner,new_start,target_end,record_id);
    update public.appointments set practitioner_id=new_practitioner,starts_at=new_start,ends_at=target_end,notes=new_notes,version=version+1 where id=record_id;
  else
    if new_status is null or not (
      (original.status='NEW' and new_status in ('PENDING','CONFIRMED','CANCELLED')) or
      (original.status='PENDING' and new_status in ('CONFIRMED','CANCELLED')) or
      (original.status='CONFIRMED' and new_status in ('IN_PROGRESS','CANCELLED','NO_SHOW')) or
      (original.status='IN_PROGRESS' and new_status in ('COMPLETED','CANCELLED'))
    ) then raise exception 'Transition de statut interdite.' using errcode='23505'; end if;
    if new_status in ('IN_PROGRESS','NO_SHOW') and original.starts_at>now() then raise exception 'Ce rendez-vous n’a pas encore commencé.' using errcode='23505'; end if;
    if new_status in ('CONFIRMED','IN_PROGRESS') then perform private.check_booking_slot(original.practitioner_id,original.starts_at,original.ends_at,record_id); end if;
    update public.appointments set status=new_status,version=version+1 where id=record_id;
  end if;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),command,'appointments',record_id,jsonb_build_object('previous_version',original.version,'previous_status',original.status,'previous_starts_at',original.starts_at,'status',(select status from public.appointments where id=record_id),'starts_at',(select starts_at from public.appointments where id=record_id)));
  return record_id;
end $$;
revoke all on function public.change_appointment(uuid,integer,text,uuid,timestamptz,text,text) from public,anon;
grant execute on function public.change_appointment(uuid,integer,text,uuid,timestamptz,text,text) to authenticated;

create function public.appointment_details(record_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$
  select jsonb_build_object('id',a.id,'client_id',a.client_id,'client_name',c.full_name,'client_phone',c.phone,
    'practitioner_id',a.practitioner_id,'practitioner_name',p.full_name,'starts_at',a.starts_at,'ends_at',a.ends_at,
    'status',a.status,'source',a.source,'notes',a.notes,'version',a.version,
    'services',coalesce((select jsonb_agg(jsonb_build_object('service_id',s.service_id,'name',s.service_name,'duration_minutes',s.duration_minutes,'price_centimes',s.price_centimes,'quantity',s.quantity) order by s.id) from public.appointment_services s where s.appointment_id=a.id),'[]'::jsonb),
    'total_centimes',coalesce((select sum(s.price_centimes::bigint*s.quantity) from public.appointment_services s where s.appointment_id=a.id),0))
  from public.appointments a join public.clients c on c.id=a.client_id left join public.practitioners p on p.id=a.practitioner_id
  where a.id=record_id and a.deleted_at is null and private.current_role() is not null
$$;
revoke all on function public.appointment_details(uuid) from public,anon;
grant execute on function public.appointment_details(uuid) to authenticated;

create function public.appointments_day(day date, status_filter text default null, practitioner_filter uuid default null, source_filter text default null, page_number integer default 1)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare ids uuid[]; total bigint; result jsonb; day_start timestamptz := day::timestamp at time zone 'Africa/Casablanca';
  day_end timestamptz := (day+1)::timestamp at time zone 'Africa/Casablanca';
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if page_number is null or page_number not between 1 and 100000 or day is null or not isfinite(day) then raise invalid_parameter_value; end if;
  select count(*) into total from public.appointments where deleted_at is null and starts_at>=day_start and starts_at<day_end
    and (status_filter is null or status=status_filter) and (practitioner_filter is null or practitioner_id=practitioner_filter) and (source_filter is null or source=source_filter);
  select array_agg(id order by starts_at,id) into ids from (
    select id,starts_at from public.appointments where deleted_at is null and starts_at>=day_start and starts_at<day_end
      and (status_filter is null or status=status_filter) and (practitioner_filter is null or practitioner_id=practitioner_filter) and (source_filter is null or source=source_filter)
      order by starts_at,id limit 50 offset (page_number-1)*50
  ) rows;
  select coalesce(jsonb_agg(public.appointment_details(id) order by n),'[]'::jsonb) into result from unnest(ids) with ordinality t(id,n);
  return jsonb_build_object('data',result,'page',page_number,'per_page',50,'total',total,'has_more',page_number*50<total);
end $$;
revoke all on function public.appointments_day(date,text,uuid,text,integer) from public,anon;
grant execute on function public.appointments_day(date,text,uuid,text,integer) to authenticated;
