import { beforeAll, afterAll, expect, test } from 'vitest';
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { parseCatalog, databaseError } from '../src/lib/catalog';
const db = new PGlite();
const admin = '00000000-0000-4000-8000-000000000001';
const user = '00000000-0000-4000-8000-000000000002';
let service: string;
let practitioner: string;
beforeAll(async () => {
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key);
    create table auth.sessions(id uuid primary key,user_id uuid references auth.users);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select current_setting('request.jwt.claims',true)::jsonb$$;
    grant usage on schema auth to authenticated; grant execute on function auth.uid(),auth.jwt() to authenticated;`);
  // Minimal Storage SQL fixture; real Storage HTTP/signing needs a live stack.
  await db.exec(`create schema storage;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated; grant select on storage.objects to authenticated;`);
  for (const migration of ['202609090001_foundation.sql','202609090002_dashboard.sql','202609090003_catalog.sql','202609090004_availability.sql','202609090005_catalog_images.sql','202609090006_category_tree.sql']) {
    await db.exec(readFileSync(`../supabase/migrations/${migration}`, 'utf8'));
  }
  await db.exec(`insert into auth.users values('${admin}'),('${user}');
    insert into auth.sessions values('${admin}','${admin}'),('${user}','${user}');
    insert into profiles(id,full_name,role) values('${admin}','Admin','ADMIN'),('${user}','Staff','USER');`);
}, 30000);
afterAll(async () => { await db.close(); });
async function asUser(id: string) {
  await db.exec(`reset role; set request.jwt.claim.sub='${id}'; set request.jwt.claims='{"session_id":"${id}"}'; set role authenticated;`);
}
test('ADMIN creates and edits persistent catalog fields with audit events', async () => {
  await asUser(admin);
  await db.exec(`insert into service_categories(name) values('Visage');
    insert into services(name,category_id,duration_minutes,price_centimes) select 'Soin',id,30,25000 from service_categories;
    insert into practitioners(full_name,specialty,job_title,phone,email) values('Praticienne','Laser','Esthéticienne','0600000000','staff@example.test');`);
  service = (await db.query<{id: string}>('select id from services')).rows[0].id;
  practitioner = (await db.query<{id: string}>('select id from practitioners')).rows[0].id;
  await db.exec(`update services set description='Description persistée',price_centimes=30000 where id='${service}';`);
  expect((await db.query<{price_centimes: number}>('select price_centimes from services')).rows[0].price_centimes).toBe(30000);
  expect((await db.query('select * from activity_logs')).rows).toHaveLength(4);
});
test('USER direct catalog insert/archive denied and updates affect no rows', async () => {
  await asUser(user);
  for (const command of ["insert into services(name,duration_minutes,price_centimes) values('Spoof',1,1)",
    "insert into practitioners(full_name) values('Spoof')", "insert into service_categories(name) values('Spoof')"]) {
    await expect(db.exec(command)).rejects.toThrow(/row-level security/);
  }
  expect((await db.query('update services set price_centimes=0 returning id')).rows).toHaveLength(0);
  await expect(db.exec(`select archive_catalog('services','${service}')`)).rejects.toThrow(/insufficient_privilege|permission denied/);
  await expect(db.exec('delete from services')).rejects.toThrow(/permission denied/);
  await expect(db.exec('update practitioners set profile_id=auth.uid()')).rejects.toThrow(/permission denied/);
});
test('catalog archival preserves appointment references and service snapshots', async () => {
  await db.exec(`reset role;
    insert into clients(full_name) values('Client');
    insert into appointments(client_id,practitioner_id,starts_at,ends_at,source,status)
      select id,'${practitioner}',now(),now()+interval '30 minutes','MANUAL','COMPLETED' from clients;
    insert into appointment_services(appointment_id,service_id,service_name,duration_minutes,price_centimes)
      select id,'${service}','Nom historique',30,25000 from appointments;`);
  await asUser(admin);
  await db.exec(`select archive_catalog('services','${service}'); select archive_catalog('practitioners','${practitioner}');`);
  expect((await db.query<{service_name:string,price_centimes:number}>('select service_name,price_centimes from appointment_services')).rows[0]).toEqual({service_name:'Nom historique',price_centimes:25000});
  expect((await db.query('select * from appointments where practitioner_id is not null')).rows).toHaveLength(1);
  expect((await db.query('select * from services where active=false and deleted_at is not null')).rows).toHaveLength(1);
  expect((await db.query('update services set active=true returning id')).rows).toHaveLength(0);
  await expect(db.exec(`select archive_catalog('profiles','${admin}')`)).rejects.toThrow();
});
test('validation rejects unknown privilege fields, invalid money and empty updates', () => {
  expect(() => parseCatalog('practitioners', {full_name:'Test',role:'ADMIN'})).toThrow();
  expect(() => parseCatalog('services', {name:'Test',duration_minutes:30,price_centimes:1.5})).toThrow();
  expect(() => parseCatalog('services', {}, true)).toThrow();
  expect(() => databaseError({code:'42501'})).toThrow('Action non autorisée.');
});
test('availability persists atomically and rejects overlapping shifts and USER writes', async () => {
  await asUser(admin);
  const id = (await db.query<{id:string}>("insert into practitioners(full_name) values('Planning') returning id")).rows[0].id;
  const shifts = JSON.stringify([{weekday:1,starts_at:'09:00',ends_at:'12:00'},{weekday:1,starts_at:'13:00',ends_at:'18:00'}]);
  const absences = JSON.stringify([{starts_at:'2026-10-01T09:00:00+01:00',ends_at:'2026-10-01T18:00:00+01:00'}]);
  await db.query('select replace_practitioner_availability($1,$2,$3)',[id,shifts,absences]);
  expect((await db.query('select * from practitioner_schedules where practitioner_id=$1',[id])).rows).toHaveLength(2);
  const bad = JSON.stringify([{weekday:1,starts_at:'09:00',ends_at:'14:00'},{weekday:1,starts_at:'13:00',ends_at:'18:00'}]);
  await expect(db.query('select replace_practitioner_availability($1,$2,$3)',[id,bad,'[]'])).rejects.toThrow('Overlapping shifts');
  expect((await db.query('select * from practitioner_time_off where practitioner_id=$1',[id])).rows).toHaveLength(1);
  await asUser(user);
  await expect(db.query('select replace_practitioner_availability($1,$2,$3)',[id,'[]','[]'])).rejects.toThrow();
  await expect(db.exec('delete from practitioner_schedules')).rejects.toThrow(/permission denied/);
  expect((await db.query('select * from practitioner_schedules where practitioner_id=$1',[id])).rows).toHaveLength(2);
});
test('private images are readable only when linked to an accessible service', async () => {
  await asUser(admin);
  const id = (await db.query<{id:string}>("insert into services(name,duration_minutes,price_centimes) values('Photo',30,10000) returning id")).rows[0].id;
  await db.exec(`reset role; insert into storage.objects(bucket_id,name) values('service-images','${id}/photo.jpg'),('service-images','unlinked.jpg');`);
  await asUser(user);
  expect((await db.query('select * from storage.objects')).rows).toHaveLength(0);
  await expect(db.query('select set_service_image($1,$2)',[id,`${id}/photo.jpg`])).rejects.toThrow();
  await expect(db.exec("insert into storage.objects(bucket_id,name) values('service-images','bad.jpg')")).rejects.toThrow(/permission denied/);
  await asUser(admin);
  await db.query('select set_service_image($1,$2)',[id,`${id}/photo.jpg`]);
  await asUser(user);
  expect((await db.query('select * from storage.objects')).rows).toHaveLength(1);
  await asUser(admin);
  await db.query('select archive_catalog($1,$2)',['services',id]);
  await asUser(user);
  expect((await db.query('select * from storage.objects')).rows).toHaveLength(0);
});
test('category hierarchy preserves two levels and rejects cyclic moves', async () => {
  await asUser(admin);
  const parent = (await db.query<{id:string}>("insert into service_categories(name) values('Épilation') returning id")).rows[0].id;
  const child = (await db.query<{id:string}>('insert into service_categories(name,parent_id) values($1,$2) returning id',['Visage',parent])).rows[0].id;
  await expect(db.query('update service_categories set parent_id=$1 where id=$2',[child,parent])).rejects.toThrow();
  await expect(db.query('insert into service_categories(name,parent_id) values($1,$2)',['Third level',child])).rejects.toThrow();
  await expect(db.query('select archive_catalog($1,$2)',['service_categories',parent])).rejects.toThrow('Archive children first');
  await db.query('select archive_catalog($1,$2)',['service_categories',child]);
  await db.query('select archive_catalog($1,$2)',['service_categories',parent]);
});
