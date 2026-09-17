create table if not exists public.client_pack_session_adjustments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id),
  pack_id uuid not null references public.packs(id),
  delta integer not null check(delta between -100 and 100 and delta <> 0),
  reason text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.client_pack_session_adjustments enable row level security;
revoke all on public.client_pack_session_adjustments from anon,authenticated;
grant select on public.client_pack_session_adjustments to authenticated;
create policy client_pack_adjustments_read on public.client_pack_session_adjustments
  for select to authenticated using(private.current_role() is not null);

create or replace function public.adjust_client_pack_sessions(client uuid, pack uuid, session_delta integer, adjustment_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  purchased integer;
<<<<<<< HEAD
  adjusted integer;
  completed integer;
  new_total integer;
=======
  appointment_completed integer;
  manual_completed integer;
  new_completed integer;
>>>>>>> 6379105 (Allow manual client pack session adjustments)
  pack_name text;
begin
  if private.current_role() is null then raise insufficient_privilege; end if;
  if client is null or pack is null or session_delta is null or session_delta = 0 or session_delta not between -100 and 100 or length(coalesce(adjustment_reason,''))>500 then
    raise invalid_parameter_value;
  end if;
  if not exists(select 1 from public.clients where id=client and deleted_at is null) then
    raise exception 'Client introuvable.' using errcode='23503';
  end if;
  select name into pack_name from public.packs where id=pack;
  if pack_name is null then raise exception 'Pack introuvable.' using errcode='23503'; end if;

  perform pg_advisory_xact_lock(hashtext(client::text), hashtext(pack::text));

  select coalesce(sum(coalesce(p.total_sessions,1)),0)::integer,
    count(*) filter (where a.status='COMPLETED')::integer
<<<<<<< HEAD
  into purchased,completed
=======
  into purchased,appointment_completed
>>>>>>> 6379105 (Allow manual client pack session adjustments)
  from public.appointment_services aps
  join public.appointments a on a.id=aps.appointment_id
  join public.packs p on p.id=aps.pack_id
  where a.client_id=client and a.deleted_at is null and aps.pack_id=pack;

<<<<<<< HEAD
  select coalesce(sum(delta),0)::integer into adjusted
  from public.client_pack_session_adjustments
  where client_id=client and pack_id=pack;

  if purchased + adjusted <= 0 then
    raise exception 'Ce client n’a pas ce pack.' using errcode='23503';
  end if;

  new_total := purchased + adjusted + session_delta;
  if new_total < completed then
    raise exception 'Impossible de retirer une séance déjà terminée.' using errcode='23514';
  end if;
  if new_total < 0 or new_total > 1000 then raise invalid_parameter_value; end if;
=======
  if purchased <= 0 then
    raise exception 'Ce client n’a pas ce pack.' using errcode='23503';
  end if;

  select coalesce(sum(delta),0)::integer into manual_completed
  from public.client_pack_session_adjustments
  where client_id=client and pack_id=pack;

  if manual_completed + session_delta < 0 then
    raise exception 'Impossible de supprimer une séance confirmée par rendez-vous.' using errcode='23514';
  end if;

  new_completed := appointment_completed + manual_completed + session_delta;
  if new_completed > purchased then
    raise exception 'Toutes les séances du pack sont déjà terminées.' using errcode='23514';
  end if;
  if new_completed < 0 or new_completed > 1000 then raise invalid_parameter_value; end if;
>>>>>>> 6379105 (Allow manual client pack session adjustments)

  insert into public.client_pack_session_adjustments(client_id,pack_id,delta,reason,created_by)
  values(client,pack,session_delta,nullif(trim(coalesce(adjustment_reason,'')),''),auth.uid());
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
<<<<<<< HEAD
  values(auth.uid(),'SESSION_ADJUST','client_pack_session_adjustments',client,jsonb_build_object('client_id',client,'pack_id',pack,'delta',session_delta,'new_total',new_total));
=======
  values(auth.uid(),'SESSION_ADJUST','client_pack_session_adjustments',client,jsonb_build_object('client_id',client,'pack_id',pack,'delta',session_delta,'total_sessions',purchased,'completed_sessions',new_completed));
>>>>>>> 6379105 (Allow manual client pack session adjustments)

  return jsonb_build_object(
    'pack_id',pack,
    'name',pack_name,
<<<<<<< HEAD
    'total_sessions',new_total,
    'completed_sessions',completed,
    'remaining_sessions',greatest(new_total-completed,0),
    'status',case when greatest(new_total-completed,0)=0 then 'COMPLET' else 'EN_ATTENTE' end
=======
    'total_sessions',purchased,
    'completed_sessions',new_completed,
    'remaining_sessions',greatest(purchased-new_completed,0),
    'status',case when greatest(purchased-new_completed,0)=0 then 'COMPLET' else 'EN_ATTENTE' end
>>>>>>> 6379105 (Allow manual client pack session adjustments)
  );
end $$;
revoke all on function public.adjust_client_pack_sessions(uuid,uuid,integer,text) from public,anon;
grant execute on function public.adjust_client_pack_sessions(uuid,uuid,integer,text) to authenticated;

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
      max(aps.service_name) as name,
      sum(coalesce(p.total_sessions,1))::integer as purchased_sessions,
<<<<<<< HEAD
      count(*) filter (where a.status='COMPLETED')::integer as completed_sessions
=======
      count(*) filter (where a.status='COMPLETED')::integer as appointment_completed_sessions
>>>>>>> 6379105 (Allow manual client pack session adjustments)
    from public.appointment_services aps
    join public.appointments a on a.id=aps.appointment_id
    join public.packs p on p.id=aps.pack_id
    where a.client_id=record_id and a.deleted_at is null and aps.pack_id is not null
    group by aps.pack_id
  ), pack_usage as (
    select
      pp.pack_id,
      pp.name,
<<<<<<< HEAD
      greatest(pp.purchased_sessions + coalesce((
        select sum(adj.delta) from public.client_pack_session_adjustments adj
        where adj.client_id=record_id and adj.pack_id=pp.pack_id
      ),0),0)::integer as total_sessions,
      pp.completed_sessions
=======
      pp.purchased_sessions::integer as total_sessions,
      least(pp.purchased_sessions, greatest(pp.appointment_completed_sessions + coalesce((
        select sum(adj.delta) from public.client_pack_session_adjustments adj
        where adj.client_id=record_id and adj.pack_id=pp.pack_id
      ),0),0))::integer as completed_sessions
>>>>>>> 6379105 (Allow manual client pack session adjustments)
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
