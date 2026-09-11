-- Ledger entries remain immutable; corrections are separate signed movements.
create table private.inventory_requests (
  actor_id uuid not null references public.profiles(id),
  request_id uuid not null,
  payload jsonb not null,
  transaction_id uuid not null references public.inventory_transactions(id),
  primary key(actor_id,request_id)
);

create function public.adjust_inventory(product uuid, quantity_delta numeric, reason_text text, request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare original public.products%rowtype; previous private.inventory_requests%rowtype;
  payload jsonb; balance numeric; result uuid;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if product is null or request_key is null or quantity_delta is null
    or quantity_delta::text in ('NaN','Infinity','-Infinity')
    or quantity_delta=0 or abs(quantity_delta)>999999999.999
    or quantity_delta<>round(quantity_delta,3)
    or reason_text is null or length(btrim(reason_text)) not between 3 and 500 then
    raise invalid_parameter_value;
  end if;
  -- Serialize command retries as well as balance checks until per-product request locking is needed.
  perform pg_advisory_xact_lock(198413,7);
  payload:=jsonb_build_object('product',product,'quantity',quantity_delta,'reason',btrim(reason_text));
  select * into previous from private.inventory_requests where actor_id=auth.uid() and request_id=request_key;
  if found then
    if previous.payload<>payload then raise exception 'Clé de mouvement déjà utilisée.' using errcode='23505'; end if;
    return previous.transaction_id;
  end if;
  select * into original from public.products where id=product for update;
  if not found then return null; end if;
  if not original.active or original.deleted_at is not null then
    raise exception 'Produit inactif. Actualisez la fiche.' using errcode='23505';
  end if;
  select coalesce(sum(quantity),0) into balance from public.inventory_transactions where product_id=product;
  if balance+quantity_delta<0 then raise exception 'Stock insuffisant.' using errcode='23505'; end if;
  insert into public.inventory_transactions(product_id,recorded_by,quantity,reason)
    values(product,auth.uid(),quantity_delta,btrim(reason_text)) returning id into result;
  insert into private.inventory_requests values(auth.uid(),request_key,payload,result);
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'CREATE','inventory_transactions',result,
      jsonb_build_object('product_id',product,'previous_quantity',balance,'quantity',quantity_delta,'new_quantity',balance+quantity_delta));
  return result;
end $$;
revoke all on function public.adjust_inventory(uuid,numeric,text,uuid) from public,anon;
grant execute on function public.adjust_inventory(uuid,numeric,text,uuid) to authenticated;
