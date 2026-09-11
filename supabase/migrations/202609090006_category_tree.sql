alter table public.service_categories add column parent_id uuid references public.service_categories(id),
  add column sort_order integer not null default 0 check(sort_order between 0 and 10000),
  add constraint category_not_own_parent check(parent_id is distinct from id);
grant insert(parent_id,sort_order),update(parent_id,sort_order) on public.service_categories to authenticated;
create index category_parent_idx on public.service_categories(parent_id,sort_order);

-- The reference uses two levels. Serialize tree mutations to prevent concurrent
-- moves creating a cycle or adding a third level.
create function private.guard_category_tree() returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform pg_advisory_xact_lock(198413,3);
  if NEW.parent_id is not null then
    if not exists(select 1 from public.service_categories where id=NEW.parent_id and parent_id is null and deleted_at is null)
      or exists(select 1 from public.service_categories where parent_id=NEW.id and deleted_at is null) then
      raise exception 'Two-level category tree required' using errcode='23514'; end if;
  end if;
  if NEW.deleted_at is not null and exists(select 1 from public.service_categories where parent_id=NEW.id and deleted_at is null) then
    raise exception 'Archive children first' using errcode='23503'; end if;
  return NEW;
end $$;
revoke all on function private.guard_category_tree() from public,anon,authenticated;
create trigger guard_category_tree before insert or update on public.service_categories for each row execute function private.guard_category_tree();
