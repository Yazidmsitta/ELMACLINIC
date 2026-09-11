create or replace function public.replace_practitioner_availability(practitioner uuid, shifts jsonb, absences jsonb)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  perform 1 from public.practitioners where id=practitioner and deleted_at is null for update;
  if not found then return false; end if;
  if jsonb_typeof(shifts) is distinct from 'array' or jsonb_typeof(absences) is distinct from 'array'
    or jsonb_array_length(shifts)>28 or jsonb_array_length(absences)>100 then raise invalid_parameter_value; end if;
  if exists(select 1 from jsonb_to_recordset(shifts) as s(weekday integer,starts_at time,ends_at time)
    where weekday is null or weekday not between 1 and 7 or starts_at is null or ends_at is null or ends_at<=starts_at) then raise invalid_parameter_value; end if;
  if exists(select 1 from jsonb_to_recordset(absences) as s(starts_at timestamptz,ends_at timestamptz)
    where starts_at is null or ends_at is null or ends_at<=starts_at or not isfinite(starts_at) or not isfinite(ends_at)) then raise invalid_parameter_value; end if;
  if exists(select 1 from jsonb_array_elements(shifts) with ordinality a(v,n)
    join jsonb_array_elements(shifts) with ordinality b(v,n) on a.n<b.n
    where (a.v->>'weekday')::integer=(b.v->>'weekday')::integer
      and (a.v->>'starts_at')::time < (b.v->>'ends_at')::time and (b.v->>'starts_at')::time < (a.v->>'ends_at')::time) then
    raise exception 'Overlapping shifts' using errcode='23P01'; end if;
  if exists(select 1 from jsonb_array_elements(absences) with ordinality a(v,n)
    join jsonb_array_elements(absences) with ordinality b(v,n) on a.n<b.n
    where (a.v->>'starts_at')::timestamptz < (b.v->>'ends_at')::timestamptz and (b.v->>'starts_at')::timestamptz < (a.v->>'ends_at')::timestamptz) then
    raise exception 'Overlapping absences' using errcode='23P01'; end if;
  delete from public.practitioner_schedules where practitioner_id=practitioner;
  insert into public.practitioner_schedules(practitioner_id,weekday,starts_at,ends_at)
    select practitioner,weekday,starts_at,ends_at from jsonb_to_recordset(shifts) as s(weekday integer,starts_at time,ends_at time);
  delete from public.practitioner_time_off where practitioner_id=practitioner;
  insert into public.practitioner_time_off(practitioner_id,starts_at,ends_at)
    select practitioner,starts_at,ends_at from jsonb_to_recordset(absences) as s(starts_at timestamptz,ends_at timestamptz);
  -- Reject changes that strand an already reserved future appointment.
  perform private.check_booking_slot(practitioner,a.starts_at,a.ends_at,a.id)
    from public.appointments a where a.practitioner_id=practitioner and a.deleted_at is null
      and a.status in ('NEW','PENDING','CONFIRMED','IN_PROGRESS') and a.ends_at>now();
  insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'AVAILABILITY_UPDATE','practitioners',practitioner);
  return true;
end $$;
revoke all on function public.replace_practitioner_availability(uuid,jsonb,jsonb) from public,anon;
grant execute on function public.replace_practitioner_availability(uuid,jsonb,jsonb) to authenticated;
