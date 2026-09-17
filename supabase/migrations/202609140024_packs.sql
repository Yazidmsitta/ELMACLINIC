-- Pack catalogue: repeated sessions and mixed services, independently priced.
create table public.packs (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 200),
 description text, price_centimes integer not null check(price_centimes between 0 and 100000000),
 active boolean not null default true, version integer not null default 1,
 total_sessions integer not null default 1 check(total_sessions between 1 and 100),
 image_path text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.pack_items (
 pack_id uuid not null references public.packs(id), service_id uuid not null references public.services(id),
 sessions integer not null check(sessions between 1 and 100), primary key(pack_id,service_id)
);
alter table public.packs enable row level security;
alter table public.pack_items enable row level security;
revoke all on public.packs,public.pack_items from anon,authenticated;
grant select on public.packs,public.pack_items to authenticated;
create policy pack_read on public.packs for select to authenticated using(private.current_role() is not null);
create policy pack_item_read on public.pack_items for select to authenticated using(private.current_role() is not null);
create function public.save_pack(record_id uuid, pack_name text, description_text text, price integer, enabled boolean, expected_version integer, items jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; previous public.packs%rowtype;
begin
 if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
 if pack_name is null or length(trim(pack_name)) not between 1 and 200 or length(description_text)>2000 or price is null or price not between 0 and 100000000 or enabled is null
 or items is null or jsonb_typeof(items)<>'array' then raise invalid_parameter_value; end if;
 if jsonb_array_length(items) not between 1 and 30 then raise invalid_parameter_value; end if;
 if exists(select 1 from jsonb_to_recordset(items) as i(service_id uuid,sessions integer) where service_id is null or sessions is null or sessions not between 1 and 100)
 or (select count(*) from jsonb_to_recordset(items) as i(service_id uuid))<>(select count(distinct service_id) from jsonb_to_recordset(items) as i(service_id uuid)) then raise invalid_parameter_value; end if;
 -- Lock components during validation to prevent concurrent service archival.
 perform 1 from public.services where id in(select service_id from jsonb_to_recordset(items) as i(service_id uuid)) order by id for share;
 if exists(select 1 from jsonb_to_recordset(items) as i(service_id uuid) left join public.services s on s.id=i.service_id where s.id is null or s.deleted_at is not null or not s.active) then raise exception 'Prestation indisponible.' using errcode='23514'; end if;
 if record_id is null then
  if expected_version is distinct from 0 then raise invalid_parameter_value; end if;
  insert into public.packs(name,description,price_centimes,active) values(trim(pack_name),description_text,price,enabled) returning id into result;
 else
  select * into previous from public.packs where id=record_id for update;
  if not found then return null; end if;
  if previous.version is distinct from expected_version then raise exception 'Pack modifié. Actualisez la fiche.' using errcode='23505'; end if;
  result:=record_id;
  update public.packs set name=trim(pack_name),description=description_text,price_centimes=price,active=enabled,version=version+1,updated_at=now() where id=result;
  delete from public.pack_items where pack_id=result;
 end if;
 insert into public.pack_items(pack_id,service_id,sessions) select result,service_id,sessions from jsonb_to_recordset(items) as i(service_id uuid,sessions integer);
 insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),case when record_id is null then 'CREATE' else 'UPDATE' end,'packs',result);
 return result;
end $$;
revoke all on function public.save_pack(uuid,text,text,integer,boolean,integer,jsonb) from public,anon;
grant execute on function public.save_pack(uuid,text,text,integer,boolean,integer,jsonb) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('pack-images','pack-images',false,5242880,array['image/jpeg']);
create function public.set_pack_image(pack uuid, object_path text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
 if object_path is null or object_path not like pack::text||'/%' or object_path like '%..%' then raise invalid_parameter_value; end if;
 update public.packs set image_path=object_path,updated_at=now() where id=pack;
 if not found then return false; end if;
 insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'IMAGE_UPDATE','packs',pack);
 return true;
end $$;
revoke all on function public.set_pack_image(uuid,text) from public,anon;
grant execute on function public.set_pack_image(uuid,text) to authenticated;
