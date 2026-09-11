import { beforeAll,afterAll,expect,test } from 'vitest';
import { PGlite } from '@electric-sql/pglite';
import { readFileSync,readdirSync } from 'node:fs';
const db=new PGlite();
const admin='00000000-0000-4000-8000-000000000001', user='00000000-0000-4000-8000-000000000002';
let client:string,practitioner:string,service:string,start:string,appointment:string;
async function asUser(id=user) { await db.exec(`reset role;set request.jwt.claim.sub='${id}';set request.jwt.claims='{"session_id":"${id}"}';set role authenticated;`); }
beforeAll(async () => {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
    create schema auth;create table auth.users(id uuid primary key);create table auth.sessions(id uuid primary key,user_id uuid references auth.users);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select current_setting('request.jwt.claims',true)::jsonb$$;
    grant usage on schema auth to authenticated;grant execute on function auth.uid(),auth.jwt() to authenticated;
    create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;grant select on storage.objects to authenticated;`);
  for (const file of readdirSync('../supabase/migrations').filter(f=>f.endsWith('.sql')).sort()) await db.exec(readFileSync(`../supabase/migrations/${file}`,'utf8'));
  await db.exec(`insert into auth.users values('${admin}'),('${user}');insert into auth.sessions values('${admin}','${admin}'),('${user}','${user}');
    insert into profiles(id,full_name,role) values('${admin}','Admin','ADMIN'),('${user}','Staff','USER');`);
  client=(await db.query<{id:string}>("insert into clients(full_name) values('Client') returning id")).rows[0].id;
  practitioner=(await db.query<{id:string}>("insert into practitioners(full_name) values('Praticienne') returning id")).rows[0].id;
  service=(await db.query<{id:string}>("insert into services(name,duration_minutes,price_centimes) values('Soin',30,20000) returning id")).rows[0].id;
  await db.query("insert into practitioner_schedules(practitioner_id,weekday,starts_at,ends_at) select $1,d,'09:00','18:00' from generate_series(1,7) d",[practitioner]);
  start=(await db.query<{start:string}>("select (date_trunc('day',now())+interval '7 days 9 hours')::text as start")).rows[0].start;
  await asUser();
},30000);
afterAll(async()=>{await db.close();});




test('notification reads belong to the recipient and retries preserve read time',async()=>{
 await db.exec('reset role');
 const id=(await db.query<{id:string}>("insert into notifications(recipient_id,type) values($1,'TEST') returning id",[user])).rows[0].id;
 await asUser(admin);await expect(db.query('select mark_notification_read($1)',[id])).rejects.toThrow();
 await asUser();await db.query('select mark_notification_read($1)',[id]);
 const first=(await db.query<{read_at:string}>('select read_at::text from notifications where id=$1',[id])).rows[0].read_at;
 await db.query('select mark_notification_read($1)',[id]);
 expect((await db.query<{read_at:string}>('select read_at::text from notifications where id=$1',[id])).rows[0].read_at).toBe(first);
 await expect(db.query('update notifications set read_at=null')).rejects.toThrow();
});
