-- Dedicated projection: never expose practitioner contact details or internal records.
create function public.website_catalog(page_number integer default 1)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare categories jsonb; services jsonb; practitioners jsonb; total bigint;
begin
  if page_number is null or page_number not between 1 and 100000 then raise invalid_parameter_value; end if;
  with recursive visible as (
    select id,name,parent_id,sort_order from public.service_categories where parent_id is null and active and deleted_at is null
    union all select c.id,c.name,c.parent_id,c.sort_order from public.service_categories c join visible v on c.parent_id=v.id where c.active and c.deleted_at is null
  ) select coalesce(jsonb_agg(to_jsonb(v) order by sort_order,name,id),'[]'::jsonb) into categories from visible v;
  select count(*) into total from public.services s where s.active and s.deleted_at is null
    and (s.category_id is null or exists(select 1 from jsonb_array_elements(categories) c where c->>'id'=s.category_id::text));
  select coalesce(jsonb_agg(r order by r.name,r.id),'[]'::jsonb) into services from (
    select s.id,s.category_id,s.name,s.description,s.duration_minutes,s.price_centimes
    from public.services s where s.active and s.deleted_at is null
      and (s.category_id is null or exists(select 1 from jsonb_array_elements(categories) c where c->>'id'=s.category_id::text))
    order by s.name,s.id limit 50 offset (page_number-1)*50
  ) r;
  select coalesce(jsonb_agg(r order by r.full_name,r.id),'[]'::jsonb) into practitioners from (
    select id,full_name,specialty from public.practitioners where active and deleted_at is null
  ) r;
  return jsonb_build_object('categories',categories,'services',services,'practitioners',practitioners,
    'currency','MAD','page',page_number,'per_page',50,'total_services',total,'has_more',page_number*50<total);
end $$;
revoke all on function public.website_catalog(integer) from public,anon,authenticated;
grant execute on function public.website_catalog(integer) to service_role;
