create function public.save_clinic_settings(clinic_name text,phone_text text,address_text text)
returns void language plpgsql security definer set search_path='' as $$
declare previous jsonb; next_value jsonb; result uuid;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if clinic_name is null or length(btrim(clinic_name)) not between 1 and 200
    or phone_text is null or length(phone_text)>40 or address_text is null or length(address_text)>1000 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,9);
  select value into previous from public.settings where key='clinic_profile';
  next_value:=jsonb_build_object('name',btrim(clinic_name),'phone',btrim(phone_text),'address',btrim(address_text));
  insert into public.settings(key,category,value,updated_by) values('clinic_profile','clinic',next_value,auth.uid())
    on conflict(key) do update set value=excluded.value,updated_by=excluded.updated_by returning id into result;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'UPDATE','settings',result,jsonb_build_object('previous',previous));
end $$;
revoke all on function public.save_clinic_settings(text,text,text) from public,anon;
grant execute on function public.save_clinic_settings(text,text,text) to authenticated;
