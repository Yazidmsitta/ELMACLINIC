create function public.archive_imported_website_booking(event_record uuid, expected_version integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare incoming public.website_booking_events%rowtype;
begin
  if private.current_role()<>'ADMIN' then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(198413,4);
  select * into incoming from public.website_booking_events where id=event_record for update;
  if not found then return null; end if;
  if incoming.version is distinct from expected_version or incoming.state<>'IMPORTED'
    or incoming.appointment_id is null then
    raise exception 'Réservation modifiée. Actualisez la fiche.' using errcode='23505';
  end if;
  update public.appointments set deleted_at=now(),version=version+1
    where id=incoming.appointment_id and deleted_at is null;
  if not found then raise exception 'Rendez-vous introuvable.' using errcode='P0002'; end if;
  update public.website_booking_events set state='DISMISSED',
    dismissal_reason='Rendez-vous importé archivé.', reviewed_by=auth.uid(),
    reviewed_at=now(), version=version+1 where id=event_record;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'ARCHIVE','website_booking_events',event_record,
      jsonb_build_object('appointment_id',incoming.appointment_id,'previous_version',incoming.version));
  return event_record;
end $$;
revoke all on function public.archive_imported_website_booking(uuid,integer) from public,anon;
grant execute on function public.archive_imported_website_booking(uuid,integer) to authenticated;