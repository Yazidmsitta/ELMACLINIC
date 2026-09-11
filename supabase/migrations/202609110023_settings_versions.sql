alter table public.settings add column version integer not null default 1 check(version>0);
drop function public.save_clinic_settings(text,text,text);
create function public.save_clinic_settings(clinic_name text,phone_text text,address_text text,expected_version integer)
returns integer language plpgsql security definer set search_path='' as $$
declare previous public.settings%rowtype; next_value jsonb; result uuid; new_version integer;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if clinic_name is null or length(btrim(clinic_name)) not between 1 and 200
    or phone_text is null or length(phone_text)>40 or address_text is null or length(address_text)>1000
    or expected_version is null or expected_version<0 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,9);
  select * into previous from public.settings where key='clinic_profile' for update;
  if coalesce(previous.version,0)<>expected_version then
    raise exception 'Paramètres modifiés. Actualisez avant de sauvegarder.' using errcode='23505'; end if;
  next_value:=jsonb_build_object('name',btrim(clinic_name),'phone',btrim(phone_text),'address',btrim(address_text));
  insert into public.settings(key,category,value,updated_by) values('clinic_profile','clinic',next_value,auth.uid())
    on conflict(key) do update set value=excluded.value,updated_by=excluded.updated_by,version=public.settings.version+1
    returning id,version into result,new_version;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'UPDATE','settings',result,jsonb_build_object('previous',previous.value,'version',new_version));
  return new_version;
end $$;
revoke all on function public.save_clinic_settings(text,text,text,integer) from public,anon;
grant execute on function public.save_clinic_settings(text,text,text,integer) to authenticated;
