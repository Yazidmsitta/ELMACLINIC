create or replace function public.save_product(
  sku_text text, name_text text, description_text text, unit_text text,
  cost integer, threshold numeric, initial_quantity numeric,
  enabled boolean, record_id uuid default null, expected_version integer default null
)
returns uuid language plpgsql security definer set search_path='' as $$
declare original public.products%rowtype; result uuid;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if sku_text is null or length(btrim(sku_text)) not between 1 and 100
    or name_text is null or length(btrim(name_text)) not between 1 and 200
    or length(coalesce(description_text,'')) > 500
    or unit_text is null or length(btrim(unit_text)) not between 1 and 40
    or cost is null or cost<0 or threshold is null or threshold<0
    or initial_quantity is null or initial_quantity<0 or enabled is null
    or threshold<>round(threshold,3) or initial_quantity<>round(initial_quantity,3) then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,7);
  if record_id is null then
    insert into public.products(sku,name,description,unit,cost_centimes,reorder_level,active)
      values(btrim(sku_text),btrim(name_text),btrim(coalesce(description_text,'')),btrim(unit_text),cost,threshold,enabled) returning id into result;
    if initial_quantity > 0 then
      insert into public.inventory_transactions(product_id,recorded_by,quantity,reason) values(result,auth.uid(),initial_quantity,'Stock initial');
    end if;
  else
    select * into original from public.products where id=record_id for update;
    if not found or original.version is distinct from expected_version or original.deleted_at is not null then raise exception 'Produit modifié. Actualisez la fiche.' using errcode='23505'; end if;
    update public.products set sku=btrim(sku_text),name=btrim(name_text),description=btrim(coalesce(description_text,'')),unit=btrim(unit_text),cost_centimes=cost,reorder_level=threshold,active=enabled,version=version+1 where id=record_id;
    result:=record_id;
  end if;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),case when record_id is null then 'CREATE' else 'UPDATE' end,'products',result);
  return result;
end $$;
revoke all on function public.save_product(text,text,text,text,integer,numeric,numeric,boolean,uuid,integer) from public,anon;
grant execute on function public.save_product(text,text,text,text,integer,numeric,numeric,boolean,uuid,integer) to authenticated;
