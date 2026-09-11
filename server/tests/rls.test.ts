import { beforeAll, afterAll, expect, test } from 'vitest';
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
const db = new PGlite();
const admin = '00000000-0000-4000-8000-000000000001';
const user = '00000000-0000-4000-8000-000000000002';
const session = '00000000-0000-4000-8000-000000000003';
beforeAll(async () => {
  // Test-only Supabase Auth contract fixture; production uses real auth schema.
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key);
    create table auth.sessions(id uuid primary key,user_id uuid references auth.users);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select current_setting('request.jwt.claims',true)::jsonb$$;
    grant usage on schema auth to authenticated;
    grant execute on function auth.uid(),auth.jwt() to authenticated;`);
  await db.exec(readFileSync('../supabase/migrations/202609090001_foundation.sql','utf8'));
  await db.exec(readFileSync('../supabase/migrations/202609090002_dashboard.sql','utf8'));
  await db.exec(`insert into auth.users values('${admin}'),('${user}');
    insert into auth.sessions values('${admin}','${admin}'),('${session}','${user}');
    insert into profiles(id,full_name,role) values('${admin}','Admin','ADMIN'),('${user}','User','USER');
    insert into services(name,duration_minutes,price_centimes) values('Soin',30,20000);
    insert into expenses(description,category,amount_centimes,spent_on,recorded_by) values('Test','Test',100,current_date,'${admin}');`);
}, 30000);
afterAll(async () => { await db.close(); });
async function asUser(id = user, sid = session) {
  await db.exec(`reset role; set request.jwt.claim.sub='${id}'; set request.jwt.claims='{"session_id":"${sid}"}'; set role authenticated;`);
}
test('USER reads catalog but cannot change prices or own role', async () => {
  await asUser();
  expect((await db.query('select * from services')).rows).toHaveLength(1);
  await expect(db.exec('update services set price_centimes=0')).rejects.toThrow(/permission denied/);
  await expect(db.exec("update profiles set role='ADMIN'")).rejects.toThrow(/permission denied/);
});
test('USER cannot read sensitive financial data; ADMIN can', async () => {
  await asUser();
  expect((await db.query('select * from expenses')).rows).toHaveLength(0);
  await asUser(admin,admin);
  expect((await db.query('select * from expenses')).rows).toHaveLength(1);
});
test('basic client writes allowed; owner spoofing denied', async () => {
  await asUser();
  await db.exec(`insert into clients(full_name,created_by) values('Client','${user}')`);
  await expect(db.exec(`insert into clients(full_name,created_by) values('Spoof','${admin}')`)).rejects.toThrow(/row-level security/);
  await expect(db.exec('delete from clients')).rejects.toThrow(/permission denied/);
});
test('revoked session and disabled account lose database access', async () => {
  await asUser(user,admin);
  expect((await db.query('select * from services')).rows).toHaveLength(0);
  await db.exec(`reset role; update profiles set active=false where id='${user}'`);
  await asUser();
  expect((await db.query('select * from services')).rows).toHaveLength(0);
  await db.exec(`reset role; update profiles set active=true where id='${user}'`);
});
test('anonymous and authenticated callers cannot use privileged rate limiter', async () => {
  await db.exec('reset role; set role anon');
  await expect(db.exec('select * from clients')).rejects.toThrow(/permission denied/);
  await asUser();
  await expect(db.exec("select consume_auth_limit('test',1)")).rejects.toThrow(/permission denied/);
  await db.exec('reset role; set role service_role');
  expect((await db.query<{consume_auth_limit:boolean}>("select consume_auth_limit('test',1)")).rows[0].consume_auth_limit).toBe(true);
  expect((await db.query<{consume_auth_limit:boolean}>("select consume_auth_limit('test',1)")).rows[0].consume_auth_limit).toBe(false);
});
test('notifications are recipient-scoped and ADMIN archival preserves history', async () => {
  await db.exec(`reset role; insert into notifications(recipient_id,type) values('${admin}','TEST'),('${user}','TEST');`);
  await asUser();
  expect((await db.query('select * from notifications')).rows).toHaveLength(1);
  await expect(db.exec(`select archive_client((select id from clients limit 1))`)).rejects.toThrow();
  await asUser(admin,admin);
  await db.exec('select archive_client((select id from clients limit 1))');
  expect((await db.query('select * from clients where deleted_at is not null')).rows).toHaveLength(1);
  expect((await db.query('select * from activity_logs')).rows).toHaveLength(1);
});
test('all core tables have RLS; invalid appointment sources and intervals are rejected', async () => {
  await db.exec('reset role');
  expect((await db.query("select * from pg_tables where schemaname='public' and not rowsecurity")).rows).toHaveLength(0);
  await expect(db.exec("insert into appointments(client_id,starts_at,ends_at,source) select id,now(),now()+interval '1 hour','APPLICATION' from clients limit 1")).rejects.toThrow(/check constraint/);
  await expect(db.exec("insert into appointments(client_id,starts_at,ends_at,source) select id,now(),now()-interval '1 hour','MANUAL' from clients limit 1")).rejects.toThrow(/check constraint/);
});
test('dashboard financial fields are absent for USER and present for ADMIN', async () => {
  await asUser();
  const staff = (await db.query<{summary: Record<string, unknown>}>('select dashboard_summary() as summary')).rows[0].summary;
  expect(staff).not.toHaveProperty('revenue_today_centimes');
  expect(staff).not.toHaveProperty('week_revenue');
  expect(staff.schedule).toEqual([]);
  await asUser(admin,admin);
  const owner = (await db.query<{summary: Record<string, unknown>}>('select dashboard_summary() as summary')).rows[0].summary;
  expect(owner.revenue_today_centimes).toBe(0);
  expect(owner.week_revenue).toHaveLength(7);
});
test('dashboard aggregates persisted appointments and payments in clinic time', async () => {
  await db.exec(`reset role;
    insert into appointments(client_id,starts_at,ends_at,source,status)
      select id, ((now() at time zone 'Africa/Casablanca')::date + time '10:00') at time zone 'Africa/Casablanca',
      ((now() at time zone 'Africa/Casablanca')::date + time '10:30') at time zone 'Africa/Casablanca', 'WEBSITE','PENDING' from clients limit 1;
    insert into appointment_services(appointment_id,service_id,service_name,duration_minutes,price_centimes)
      select a.id,s.id,'Soin historique',30,20000 from appointments a cross join services s limit 1;
    insert into payments(appointment_id,recorded_by,amount_centimes,method,idempotency_key)
      select id,'${user}',20000,'CASH',gen_random_uuid() from appointments limit 1;`);
  await asUser(admin,admin);
  const result = (await db.query<{summary: Record<string, unknown>}>('select dashboard_summary() as summary')).rows[0].summary;
  expect(result.appointments_today).toBe(1);
  expect(result.pending).toBe(1);
  expect(result.revenue_today_centimes).toBe(20000);
  expect(result.schedule).toEqual([expect.objectContaining({ time: '10:00', duration: 30, service_name: 'Soin historique', source: 'WEBSITE' })]);
});
