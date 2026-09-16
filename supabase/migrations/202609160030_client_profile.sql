-- Backfill packs created before total_sessions existed from their configured pack items.
update public.packs p set total_sessions = greatest(1, coalesce((
  select max(pi.sessions) from public.pack_items pi where pi.pack_id=p.id
), p.total_sessions));

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

  with pack_usage as (
    select
      aps.pack_id,
      max(aps.service_name) as name,
      sum(coalesce(p.total_sessions,1))::integer as total_sessions,
      count(*) filter (where a.status='COMPLETED')::integer as completed_sessions
    from public.appointment_services aps
    join public.appointments a on a.id=aps.appointment_id
    join public.packs p on p.id=aps.pack_id
    where a.client_id=record_id and a.deleted_at is null and aps.pack_id is not null
    group by aps.pack_id
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
