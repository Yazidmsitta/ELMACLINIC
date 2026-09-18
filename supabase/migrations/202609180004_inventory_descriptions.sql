alter table public.products
  add column if not exists description text not null default '' check(length(description) <= 500);

create or replace function public.save_product(
  sku_text text,
  name_text text,
  description_text text,
  unit_text text,
  cost integer,
  threshold numeric,
  enabled boolean,
  record_id uuid default null,
  expected_version integer default null
)
returns uuid language plpgsql security definer set search_path='' as $$
declare original public.products%rowtype; result uuid;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if sku_text is null or length(btrim(sku_text)) not between 1 and 100
    or name_text is null or length(btrim(name_text)) not between 1 and 200
    or length(coalesce(description_text,'')) > 500
    or unit_text is null or length(btrim(unit_text)) not between 1 and 40
    or cost is null or cost<0 or enabled is null or threshold is null
    or threshold::text in ('NaN','Infinity','-Infinity') or threshold<0 or threshold>999999999.999
    or threshold<>round(threshold,3) then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,7);
  if record_id is null then
    insert into public.products(sku,name,description,unit,cost_centimes,reorder_level,active)
      values(btrim(sku_text),btrim(name_text),btrim(coalesce(description_text,'')),btrim(unit_text),cost,threshold,enabled) returning id into result;
  else
    select * into original from public.products where id=record_id for update;
    if not found then return null; end if;
    if original.version is distinct from expected_version or original.deleted_at is not null then
      raise exception 'Produit modifié. Actualisez la fiche.' using errcode='23505'; end if;
    if original.unit<>btrim(unit_text) and exists(select 1 from public.inventory_transactions where product_id=record_id) then
      raise exception 'Unité liée à des mouvements historiques.' using errcode='23505'; end if;
    update public.products set sku=btrim(sku_text),name=btrim(name_text),description=btrim(coalesce(description_text,'')),unit=btrim(unit_text),cost_centimes=cost,
      reorder_level=threshold,active=enabled,version=version+1 where id=record_id;
    result:=record_id;
  end if;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),case when record_id is null then 'CREATE' else 'UPDATE' end,'products',result,
      jsonb_build_object('previous',case when record_id is null then null else to_jsonb(original) end));
  return result;
end $$;
revoke all on function public.save_product(text,text,text,text,integer,numeric,boolean,uuid,integer) from public,anon;
grant execute on function public.save_product(text,text,text,text,integer,numeric,boolean,uuid,integer) to authenticated;

create or replace function public.inventory_list(page_number integer default 1)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb; total bigint;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if page_number is null or page_number not between 1 and 100000 then raise invalid_parameter_value; end if;
  select count(*) into total from public.products where deleted_at is null;
  select coalesce(jsonb_agg(r order by r.name,r.id),'[]'::jsonb) into rows from (
    select p.id,p.sku,p.name,p.description,p.unit,p.cost_centimes,p.active,p.version,p.reorder_level::text,
      coalesce((select sum(t.quantity) from public.inventory_transactions t where t.product_id=p.id),0)::text as quantity
    from public.products p where p.deleted_at is null order by p.name,p.id limit 50 offset (page_number-1)*50
  ) r;
  return jsonb_build_object('data',rows,'total',total,'page',page_number,'per_page',50,'has_more',page_number*50<total);
end $$;
revoke all on function public.inventory_list(integer) from public,anon;
grant execute on function public.inventory_list(integer) to authenticated;
