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

let receipt:string;
async function receive(eventId='event-1', bookingId='website-1', slot=start) {
  await db.exec('reset role; set role service_role');
  return db.query<{data:{id:string,replayed:boolean}}>('select receive_website_booking($1) as data',[JSON.stringify({
    provider:'elmaclinic.ma',source:'WEBSITE',event_id:eventId,booking_id:bookingId,
    occurred_at:'2026-01-01T10:00:00Z',starts_at:slot,notes:null,
  })]);
}
async function resolve(id=receipt) {
  return db.query<{id:string}>('select import_website_booking($1,1,$2,$3,$4,20000,30) as id',[id,client,practitioner,[service]]);
}
test('only service role may enqueue; identical delivery reuses durable receipt',async()=>{
  await expect(db.query('select receive_website_booking($1)',['{}'])).rejects.toThrow(/permission denied/);
  receipt=(await receive()).rows[0].data.id;
  const replay=(await receive()).rows[0].data;
  expect(replay.id).toBe(receipt);expect(replay.replayed).toBe(true);
  await expect(receive('event-1','different')).rejects.toThrow('déjà utilisé');
});
test('staff can read pending queue but cannot bypass review command',async()=>{
  await asUser();expect((await db.query('select * from website_booking_events')).rows).toHaveLength(1);
  await expect(db.exec("update website_booking_events set state='IMPORTED'")).rejects.toThrow(/permission denied/);
});
test('review creates WEBSITE NEW appointment, snapshots and notifications atomically',async()=>{
  appointment=(await resolve()).rows[0].id;
  const row=(await db.query<{source:string,status:string}>('select * from appointments where id=$1',[appointment])).rows[0];
  expect(row.source).toBe('WEBSITE');expect(row.status).toBe('NEW');
  expect((await db.query('select * from appointment_services where appointment_id=$1',[appointment])).rows).toHaveLength(1);
  expect((await db.query('select * from notifications where appointment_id=$1',[appointment])).rows).toHaveLength(1);
  await expect(resolve()).rejects.toThrow('Actualisez');
  await receive();await asUser();
  expect((await db.query('select * from notifications where appointment_id=$1',[appointment])).rows).toHaveLength(1);
});
test('conflicting slot rolls back import and retains review state',async()=>{
  const id=(await receive('event-2','website-2')).rows[0].data.id;await asUser();
  await expect(resolve(id)).rejects.toThrow('déjà réservé');
  expect((await db.query<{state:string}>('select state from website_booking_events where id=$1',[id])).rows[0].state).toBe('REVIEW');
});
test('another event cannot duplicate or overwrite an already imported booking',async()=>{
  const id=(await receive('event-3','website-1')).rows[0].data.id;await asUser();
  await expect(resolve(id)).rejects.toThrow('existante');
});
test('dismissal requires a reason and current review version; replay cannot reopen it',async()=>{
  const id=(await receive('event-dismiss','website-dismiss')).rows[0].data.id;await asUser();
  await expect(db.query('select dismiss_website_booking($1,1,$2)',[id,' '])).rejects.toThrow();
  await db.query('select dismiss_website_booking($1,1,$2)',[id,'Doublon vérifié']);
  const row=(await db.query<{state:string,version:number,dismissal_reason:string}>('select * from website_booking_events where id=$1',[id])).rows[0];
  expect(row.state).toBe('DISMISSED');expect(row.version).toBe(2);expect(row.dismissal_reason).toBe('Doublon vérifié');
  await expect(resolve(id)).rejects.toThrow('Actualisez');
  await expect(db.query('select dismiss_website_booking($1,1,$2)',[id,'Doublon vérifié'])).rejects.toThrow('Actualisez');
  await receive('event-dismiss','website-dismiss');await asUser();
  expect((await db.query<{state:string}>('select state from website_booking_events where id=$1',[id])).rows[0].state).toBe('DISMISSED');
  await expect(db.query('select dismiss_website_booking($1,2,$2)',[receipt,'Ne pas annuler un rendez-vous importé'])).rejects.toThrow('Actualisez');
});

test('anonymous access is denied and disabled staff lose inbox access',async()=>{
  await db.exec('reset role;set role anon');
  await expect(db.exec('select * from website_booking_events')).rejects.toThrow(/permission denied/);
  await db.exec('reset role');await db.query('update profiles set active=false where id=$1',[user]);await asUser();
  expect((await db.query('select * from website_booking_events')).rows).toHaveLength(0);
  await expect(resolve()).rejects.toThrow();
});
