alter table public.services add column image_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('service-images','service-images',false,2097152,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=array['image/jpeg'];

-- Uploads go through the authenticated Next image sanitizer. No client writes.
create policy service_image_read on storage.objects for select to authenticated using(
  bucket_id='service-images' and private.current_role() is not null and exists(
    select 1 from public.services s where s.image_path=storage.objects.name and s.deleted_at is null
      and (s.active or private.current_role()='ADMIN')
  )
);
create function public.set_service_image(service uuid, object_path text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if object_path is not null and (object_path not like service::text || '/%'
    or not exists(select 1 from storage.objects where bucket_id='service-images' and name=object_path)) then
    raise invalid_parameter_value; end if;
  update public.services set image_path=object_path where id=service and deleted_at is null;
  return found;
end $$;
revoke all on function public.set_service_image(uuid,text) from public,anon;
grant execute on function public.set_service_image(uuid,text) to authenticated;
