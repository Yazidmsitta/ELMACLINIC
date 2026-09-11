alter table public.profiles add column version integer not null default 1 check(version>0);
create function public.update_staff(record_id uuid,name_text text,role_text text,enabled boolean,expected_version integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare original public.profiles%rowtype;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if name_text is null or length(btrim(name_text)) not between 1 and 200
    or role_text is null or role_text not in ('ADMIN','USER') or enabled is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,8);
  select * into original from public.profiles where id=record_id for update;
  if not found then return null; end if;
  if original.version is distinct from expected_version then
    raise exception 'Utilisateur modifié. Actualisez la fiche.' using errcode='23505'; end if;
  if original.role='ADMIN' and original.active and (role_text<>'ADMIN' or not enabled)
    and not exists(select 1 from public.profiles where id<>record_id and role='ADMIN' and active) then
    raise exception 'Un administrateur actif est requis.' using errcode='23505'; end if;
  update public.profiles set full_name=btrim(name_text),role=role_text,active=enabled,version=version+1 where id=record_id;
  if original.role<>role_text or original.active<>enabled then
    delete from auth.sessions where user_id=record_id;
  end if;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'UPDATE','profiles',record_id,jsonb_build_object('previous',to_jsonb(original),'version',original.version+1));
  return record_id;
end $$;
revoke all on function public.update_staff(uuid,text,text,boolean,integer) from public,anon;
grant execute on function public.update_staff(uuid,text,text,boolean,integer) to authenticated;
