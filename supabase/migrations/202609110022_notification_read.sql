revoke update(read_at) on public.notifications from authenticated;
create function public.mark_notification_read(record_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  select recipient_id into recipient from public.notifications where id=record_id for update;
  if not found then return null; end if;
  if recipient<>auth.uid() then raise insufficient_privilege; end if;
  update public.notifications set read_at=coalesce(read_at,now()) where id=record_id;
  return record_id;
end $$;
revoke all on function public.mark_notification_read(uuid) from public,anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;
