alter table public.products add column image_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('product-images','product-images',false,5242880,array['image/jpeg']);
create function public.set_product_image(product uuid, object_path text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
 if object_path is null or object_path not like product::text||'/%' or object_path like '%..%' then raise invalid_parameter_value; end if;
 update public.products set image_path=object_path,updated_at=now() where id=product;
 if not found then return false; end if;
 insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'IMAGE_UPDATE','products',product);
 return true;
end $$;
revoke all on function public.set_product_image(uuid,text) from public,anon;
grant execute on function public.set_product_image(uuid,text) to authenticated;
