alter table public.website_booking_events add column dismissal_reason text
  check(dismissal_reason is null or length(btrim(dismissal_reason)) between 3 and 500);

create function public.dismiss_website_booking(event_record uuid, expected_version integer, reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare incoming public.website_booking_events%rowtype;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if reason is null or length(btrim(reason)) not between 3 and 500 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into incoming from public.website_booking_events where id=event_record for update;
  if not found then return null; end if;
  if incoming.version is distinct from expected_version or incoming.state<>'REVIEW' then
    raise exception 'Réservation modifiée. Actualisez la fiche.' using errcode='23505';
  end if;
  update public.website_booking_events set state='DISMISSED',dismissal_reason=btrim(reason),
    reviewed_by=auth.uid(),reviewed_at=now(),version=version+1 where id=event_record;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'DISMISS','website_booking_events',event_record,jsonb_build_object('previous_version',incoming.version));
  return event_record;
end $$;
revoke all on function public.dismiss_website_booking(uuid,integer,text) from public,anon;
grant execute on function public.dismiss_website_booking(uuid,integer,text) to authenticated;
