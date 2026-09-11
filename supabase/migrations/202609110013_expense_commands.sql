alter table public.expenses add column version integer not null default 1 check(version>0);
alter table public.expenses add column void_reason text;
create table private.expense_requests (
  actor_id uuid not null references public.profiles(id), request_id uuid not null,
  payload jsonb not null, expense_id uuid not null references public.expenses(id),
  primary key(actor_id,request_id)
);
create function public.save_expense(description_text text, category_text text, amount integer, expense_date date,
  request_key uuid default null, record_id uuid default null, expected_version integer default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; original public.expenses%rowtype; previous private.expense_requests%rowtype; payload jsonb;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if description_text is null or length(btrim(description_text)) not between 1 and 2000
    or category_text is null or length(btrim(category_text)) not between 1 and 100
    or amount is null or amount<=0 or expense_date is null or not isfinite(expense_date) then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,6);
  payload:=jsonb_build_object('description',btrim(description_text),'category',btrim(category_text),'amount',amount,'date',expense_date);
  if record_id is null then
    if request_key is null then raise invalid_parameter_value; end if;
    select * into previous from private.expense_requests where actor_id=auth.uid() and request_id=request_key;
    if found then
      if previous.payload<>payload then raise exception 'Clé de dépense déjà utilisée.' using errcode='23505'; end if;
      return previous.expense_id;
    end if;
    insert into public.expenses(description,category,amount_centimes,spent_on,recorded_by)
      values(btrim(description_text),btrim(category_text),amount,expense_date,auth.uid()) returning id into result;
    insert into private.expense_requests values(auth.uid(),request_key,payload,result);
    insert into public.activity_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'CREATE','expenses',result);
  else
    select * into original from public.expenses where id=record_id for update;
    if not found then return null; end if;
    if original.version is distinct from expected_version or original.voided_at is not null then
      raise exception 'Dépense modifiée ou annulée. Actualisez la fiche.' using errcode='23505';
    end if;
    update public.expenses set description=btrim(description_text),category=btrim(category_text),amount_centimes=amount,spent_on=expense_date,version=version+1 where id=record_id;
    insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
      values(auth.uid(),'UPDATE','expenses',record_id,jsonb_build_object('previous',to_jsonb(original),'version',original.version+1));
    result:=record_id;
  end if;
  return result;
end $$;
revoke all on function public.save_expense(text,text,integer,date,uuid,uuid,integer) from public,anon;
grant execute on function public.save_expense(text,text,integer,date,uuid,uuid,integer) to authenticated;

create function public.void_expense(record_id uuid, expected_version integer, reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare original public.expenses%rowtype;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if reason is null or length(btrim(reason)) not between 3 and 500 then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(198413,6);
  select * into original from public.expenses where id=record_id for update;
  if not found then return null; end if;
  if original.version is distinct from expected_version or original.voided_at is not null then
    raise exception 'Dépense modifiée ou annulée. Actualisez la fiche.' using errcode='23505';
  end if;
  update public.expenses set voided_at=now(),void_reason=btrim(reason),version=version+1 where id=record_id;
  insert into public.activity_logs(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'VOID','expenses',record_id,jsonb_build_object('previous_version',original.version));
  return record_id;
end $$;
revoke all on function public.void_expense(uuid,integer,text) from public,anon;
grant execute on function public.void_expense(uuid,integer,text) to authenticated;
