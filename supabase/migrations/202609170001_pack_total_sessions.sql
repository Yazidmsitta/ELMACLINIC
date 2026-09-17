alter table public.packs
  add column if not exists total_sessions integer not null default 1 check(total_sessions between 1 and 100);

update public.packs p
set total_sessions = greatest(1, coalesce((select max(pi.sessions) from public.pack_items pi where pi.pack_id = p.id), 1))
where p.total_sessions = 1;

create or replace function public.save_pack(
  record_id uuid,
  pack_name text,
  description_text text,
  price integer,
  total_sessions integer,
  enabled boolean,
  expected_version integer,
  items jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; previous public.packs%rowtype;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if pack_name is null or length(trim(pack_name)) not between 1 and 200
    or length(coalesce(description_text,'')) > 2000
    or price is null or price not between 0 and 100000000
    or total_sessions is null or total_sessions not between 1 and 100
    or enabled is null or items is null or jsonb_typeof(items) <> 'array'
    or jsonb_array_length(items) > 30 then
    raise invalid_parameter_value;
  end if;
  if exists(
    select 1 from jsonb_to_recordset(items) as i(service_id uuid, sessions integer)
    where service_id is null or sessions is null or sessions not between 1 and 100
  ) or (select count(*) from jsonb_to_recordset(items) as i(service_id uuid)) <>
      (select count(distinct service_id) from jsonb_to_recordset(items) as i(service_id uuid)) then
    raise invalid_parameter_value;
  end if;
  if jsonb_array_length(items) > 0 then
    perform 1 from public.services
      where id in (select service_id from jsonb_to_recordset(items) as i(service_id uuid))
      order by id for share;
    if exists(
      select 1
      from jsonb_to_recordset(items) as i(service_id uuid)
      left join public.services s on s.id = i.service_id
      where s.id is null or s.deleted_at is not null or not s.active
    ) then
      raise exception 'Prestation indisponible.' using errcode='23514';
    end if;
  end if;
  if record_id is null then
    if expected_version is distinct from 0 then raise invalid_parameter_value; end if;
    insert into public.packs(name,description,price_centimes,total_sessions,active)
      values(trim(pack_name),description_text,price,total_sessions,enabled)
      returning id into result;
  else
    select * into previous from public.packs where id = record_id for update;
    if not found then return null; end if;
    if previous.version is distinct from expected_version then
      raise exception 'Pack modifié. Actualisez la fiche.' using errcode='23505';
    end if;
    result := record_id;
    update public.packs
      set name=trim(pack_name), description=description_text, price_centimes=price,
          total_sessions=total_sessions, active=enabled, version=version+1, updated_at=now()
      where id=result;
    delete from public.pack_items where pack_id=result;
  end if;
  if jsonb_array_length(items) > 0 then
    insert into public.pack_items(pack_id,service_id,sessions)
      select result,service_id,sessions
      from jsonb_to_recordset(items) as i(service_id uuid,sessions integer);
  end if;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id)
    values(auth.uid(),case when record_id is null then 'CREATE' else 'UPDATE' end,'packs',result);
  return result;
end $$;
revoke all on function public.save_pack(uuid,text,text,integer,integer,boolean,integer,jsonb) from public,anon;
grant execute on function public.save_pack(uuid,text,text,integer,integer,boolean,integer,jsonb) to authenticated;
