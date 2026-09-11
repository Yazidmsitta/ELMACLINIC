create function public.inventory_list(page_number integer default 1)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb; total bigint;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if page_number is null or page_number not between 1 and 100000 then raise invalid_parameter_value; end if;
  select count(*) into total from public.products where deleted_at is null;
  select coalesce(jsonb_agg(r order by r.name,r.id),'[]'::jsonb) into rows from (
    select p.id,p.sku,p.name,p.unit,p.cost_centimes,p.active,p.reorder_level::text,
      coalesce((select sum(t.quantity) from public.inventory_transactions t where t.product_id=p.id),0)::text as quantity
    from public.products p where p.deleted_at is null order by p.name,p.id limit 50 offset (page_number-1)*50
  ) r;
  return jsonb_build_object('data',rows,'total',total,'page',page_number,'per_page',50,'has_more',page_number*50<total);
end $$;
revoke all on function public.inventory_list(integer) from public,anon;
grant execute on function public.inventory_list(integer) to authenticated;

create function public.inventory_history(product uuid,page_number integer default 1)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb; total bigint; balance numeric;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if product is null or page_number is null or page_number not between 1 and 100000 then raise invalid_parameter_value; end if;
  if not exists(select 1 from public.products where id=product) then return null; end if;
  select count(*),coalesce(sum(quantity),0) into total,balance from public.inventory_transactions where product_id=product;
  select coalesce(jsonb_agg(r order by r.created_at desc,r.id),'[]'::jsonb) into rows from (
    select id,quantity::text,reason,recorded_by,created_at from public.inventory_transactions
      where product_id=product order by created_at desc,id limit 50 offset (page_number-1)*50
  ) r;
  return jsonb_build_object('data',rows,'quantity',balance::text,'total',total,'page',page_number,'per_page',50,'has_more',page_number*50<total);
end $$;
revoke all on function public.inventory_history(uuid,integer) from public,anon;
grant execute on function public.inventory_history(uuid,integer) to authenticated;
