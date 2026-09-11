-- Catalog writes remain guarded even when callers bypass the Next API.
alter table public.practitioners add column job_title text, add column phone text, add column email text;
alter table public.services add constraint service_name_valid check(length(btrim(name)) between 1 and 200),
  add constraint service_duration_bounded check(duration_minutes <= 1440),
  add constraint service_price_bounded check(price_centimes <= 100000000);
alter table public.practitioners add constraint practitioner_name_valid check(length(btrim(full_name)) between 1 and 200);
alter table public.service_categories add constraint category_name_valid check(length(btrim(name)) between 1 and 200);

grant insert(name,category_id,description,duration_minutes,price_centimes,active),
  update(name,category_id,description,duration_minutes,price_centimes,active) on public.services to authenticated;
grant insert(full_name,specialty,job_title,phone,email,active),
  update(full_name,specialty,job_title,phone,email,active) on public.practitioners to authenticated;
grant insert(name,active), update(name,active) on public.service_categories to authenticated;

do $$ declare t text; begin
  foreach t in array array['services','practitioners','service_categories'] loop
    execute format('create policy admin_insert on public.%I for insert to authenticated with check(private.current_role()=''ADMIN'' and deleted_at is null)', t);
    execute format('create policy admin_update on public.%I for update to authenticated using(private.current_role()=''ADMIN'' and deleted_at is null) with check(private.current_role()=''ADMIN'' and deleted_at is null)', t);
  end loop;
end $$;

create function private.audit_catalog_change() returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.activity_logs(actor_id,action,entity_type,entity_id)
  values(auth.uid(),case when TG_OP='INSERT' then 'CREATE' when NEW.deleted_at is not null and OLD.deleted_at is null then 'ARCHIVE' else 'UPDATE' end,TG_TABLE_NAME,NEW.id);
  return NEW;
end $$;
revoke all on function private.audit_catalog_change() from public,anon,authenticated;
create trigger audit_catalog after insert or update on public.services for each row execute function private.audit_catalog_change();
create trigger audit_catalog after insert or update on public.practitioners for each row execute function private.audit_catalog_change();
create trigger audit_catalog after insert or update on public.service_categories for each row execute function private.audit_catalog_change();

-- Restrict the table identifier before dynamic SQL; never delete historical rows.
create function public.archive_catalog(resource_name text, record_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
  if private.current_role() is distinct from 'ADMIN' then raise insufficient_privilege; end if;
  if resource_name not in ('services','practitioners','service_categories') then raise invalid_parameter_value; end if;
  execute format('update public.%I set active=false, deleted_at=now() where id=$1 and deleted_at is null',resource_name) using record_id;
  get diagnostics affected = row_count;
  return affected=1;
end $$;
revoke all on function public.archive_catalog(text,uuid) from public,anon;
grant execute on function public.archive_catalog(text,uuid) to authenticated;
