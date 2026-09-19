insert into public.practitioner_schedules(practitioner_id,weekday,starts_at,ends_at)
select p.id,days.weekday,'09:00'::time,'18:00'::time
from public.practitioners p
cross join generate_series(1,7) as days(weekday)
where p.deleted_at is null
  and not exists (
    select 1
    from public.practitioner_schedules existing
    where existing.practitioner_id=p.id
  );