import { beforeAll,afterAll,expect,test } from 'vitest';
import { PGlite } from '@electric-sql/pglite';
import { readFileSync,readdirSync } from 'node:fs';
const db=new PGlite();
const admin='00000000-0000-4000-8000-000000000001', user='00000000-0000-4000-8000-000000000002';
let client:string,practitioner:string,service:string,pack:string,start:string,appointment:string;
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
  await db.exec('reset role');
  pack=(await db.query<{id:string}>("insert into packs(name,price_centimes) values('Pack 8 séances',480000) returning id")).rows[0].id;
  await db.query('insert into pack_items(pack_id,service_id,sessions) values($1,$2,8)',[pack,service]);
  await db.query("insert into practitioner_schedules(practitioner_id,weekday,starts_at,ends_at) select $1,d,'09:00','18:00' from generate_series(1,7) d",[practitioner]);
  start=(await db.query<{start:string}>("select (date_trunc('day',now())+interval '7 days 9 hours')::text as start")).rows[0].start;
  await asUser();
},30000);
afterAll(async()=>{await db.close();});
async function create(key:string,slot=start,amount=20000) {
  return db.query<{id:string}>('select create_manual_appointment($1,$2,$3,$4,$5,$6,$7,$8) as id',[client,practitioner,[service],slot,'Notes',key,amount,60]);
}
async function createCart(key:string,slot:string,serviceIds:string[]=[],packIds:string[]=[pack],amount=480000,duration=60) {
  return db.query<{id:string}>('select create_manual_appointment_cart($1,$2,$3,$4,$5,$6,$7,$8,$9) as id',[client,practitioner,serviceIds,packIds,slot,'Notes',key,amount,duration]);
}
test('USER creates manual booking with authoritative price snapshots and idempotency',async()=>{
  const key='10000000-0000-4000-8000-000000000001';
  appointment=(await create(key)).rows[0].id;
  expect((await create(key)).rows[0].id).toBe(appointment);
  const details=(await db.query<{data:Record<string,unknown>}>('select appointment_details($1) as data',[appointment])).rows[0].data;
  expect(details.source).toBe('MANUAL');expect(details.status).toBe('CONFIRMED');expect(details.total_centimes).toBe(20000);
  expect(details.services).toEqual([expect.objectContaining({name:'Soin',price_centimes:20000,duration_minutes:30})]);
  await expect(create(key,start,1)).rejects.toThrow('Clé de requête déjà utilisée');
  await expect(db.exec('update appointments set source=\'WEBSITE\'')).rejects.toThrow(/permission denied/);
});
test('competing bookings cannot reserve an occupied interval; boundary adjacency is valid',async()=>{
  const result=await Promise.allSettled([create('10000000-0000-4000-8000-000000000002'),create('10000000-0000-4000-8000-000000000003')]);
  expect(result.every(r=>r.status==='rejected')).toBe(true);
  const adjacent=new Date(new Date(start).getTime()+60*60000).toISOString();
  expect((await create('10000000-0000-4000-8000-000000000004',adjacent)).rows[0].id).toBeTruthy();
});
test('pack booking uses the pack price while duration comes from included services',async()=>{
  const slot=new Date(new Date(start).getTime()+24*3600000).toISOString();
  const quote=(await db.query<{data:{total_centimes:number;duration_minutes:number;services:Array<Record<string,unknown>>}}>('select quote_appointment_cart($1,$2,$3,$4,$5) as data',[client,practitioner,[],[pack],slot])).rows[0].data;
  expect(quote.total_centimes).toBe(480000);
  expect(quote.duration_minutes).toBe(60);
  expect(quote.services).toEqual([expect.objectContaining({name:'Pack 8 séances',price_centimes:480000,type:'PACK'})]);
  const appointmentId=(await createCart('10000000-0000-4000-8000-000000000008',slot)).rows[0].id;
  const details=(await db.query<{data:{total_centimes:number;services:Array<Record<string,unknown>>}}>('select appointment_details($1) as data',[appointmentId])).rows[0].data;
  expect(details.total_centimes).toBe(480000);
  expect(details.services).toEqual([expect.objectContaining({name:'Pack 8 séances',price_centimes:480000})]);
});
test('client profile exposes today appointments, history, and pack session status',async()=>{
  const slot=new Date(new Date(start).getTime()+48*3600000).toISOString();
  await db.exec('reset role');await db.query('update packs set total_sessions=8 where id=$1',[pack]);await asUser();
  const appointmentId=(await createCart('10000000-0000-4000-8000-000000000009',slot)).rows[0].id;
  await db.exec('reset role');await db.query("update appointments set status='COMPLETED' where id=$1",[appointmentId]);await asUser();
  const profile=(await db.query<{data:{history:unknown[];packs:Array<{name:string;total_sessions:number;completed_sessions:number;remaining_sessions:number;status:string}>}}>('select client_profile($1) as data',[client])).rows[0].data;
  expect(profile.history.length).toBeGreaterThan(0);
  expect(profile.packs).toEqual([expect.objectContaining({name:'Pack 8 séances',total_sessions:16,completed_sessions:1,remaining_sessions:15,status:'EN_ATTENTE'})]);
  const added=(await db.query<{data:{total_sessions:number;completed_sessions:number;remaining_sessions:number}}>('select adjust_client_pack_sessions($1,$2,1,null) as data',[client,pack])).rows[0].data;
  expect(added.total_sessions).toBe(16);expect(added.completed_sessions).toBe(2);expect(added.remaining_sessions).toBe(14);
  const removed=(await db.query<{data:{total_sessions:number;completed_sessions:number;remaining_sessions:number}}>('select adjust_client_pack_sessions($1,$2,-1,null) as data',[client,pack])).rows[0].data;
  expect(removed.total_sessions).toBe(16);expect(removed.completed_sessions).toBe(1);expect(removed.remaining_sessions).toBe(15);
  await expect(db.query('select adjust_client_pack_sessions($1,$2,-1,null)',[client,pack])).rejects.toThrow('séance confirmée par rendez-vous');
});
test('USER cannot override prices; changed quote requires renewed confirmation',async()=>{
  const later=new Date(new Date(start).getTime()+2*3600000).toISOString();
  await expect(create('10000000-0000-4000-8000-000000000005',later,1)).rejects.toThrow('Le tarif ou la durée a changé');
  await asUser(admin);await db.query('update services set price_centimes=25000 where id=$1',[service]);await asUser();
  await expect(create('10000000-0000-4000-8000-000000000005',later)).rejects.toThrow('Le tarif ou la durée a changé');
  expect((await db.query<{data:{total_centimes:number}}>('select appointment_details($1) as data',[appointment])).rows[0].data.total_centimes).toBe(20000);
});
test('availability edits cannot strand a reserved appointment',async()=>{
  await asUser(admin);
  await expect(db.query('select replace_practitioner_availability($1,$2,$3)',[practitioner,'[]','[]'])).rejects.toThrow('créneau de travail');
  expect((await db.query('select * from practitioner_schedules where practitioner_id=$1',[practitioner])).rows).toHaveLength(7);
  await asUser();
});
test('rescheduling preserves WEBSITE source and snapshots; stale versions conflict',async()=>{
  await db.exec('reset role');await db.query("update appointments set source='WEBSITE' where id=$1",[appointment]);await asUser();
  const later=new Date(new Date(start).getTime()+3*3600000).toISOString();
  await db.query("select change_appointment($1,1,'RESCHEDULE',$2,$3,'Déplacé')",[appointment,practitioner,later]);
  const data=(await db.query<{data:Record<string,unknown>}>('select appointment_details($1) as data',[appointment])).rows[0].data;
  expect(data.source).toBe('WEBSITE');expect(data.total_centimes).toBe(20000);expect(data.version).toBe(2);
  await expect(db.query("select change_appointment($1,1,'STATUS',null,null,null,'CANCELLED')",[appointment])).rejects.toThrow('Actualisez');
});
test('status graph rejects invalid transitions and early attendance; USER cannot archive',async()=>{
  await expect(db.query("select change_appointment($1,2,'STATUS',null,null,null,'COMPLETED')",[appointment])).rejects.toThrow('Transition');
  await expect(db.query("select change_appointment($1,2,'STATUS',null,null,null,'NO_SHOW')",[appointment])).rejects.toThrow('pas encore');
  await expect(db.query("select change_appointment($1,2,'ARCHIVE')",[appointment])).rejects.toThrow();
  await db.query("select change_appointment($1,2,'STATUS',null,null,null,'CANCELLED')",[appointment]);
  expect((await db.query<{data:{status:string}}>('select appointment_details($1) as data',[appointment])).rows[0].data.status).toBe('CANCELLED');
});
test('day reads use clinic calendar boundaries and preserve unknown-id 404 data',async()=>{
  const day=(await db.query<{day:string}>("select ($1::timestamptz at time zone 'Africa/Casablanca')::date::text as day",[start])).rows[0].day;
  const data=(await db.query<{data:{total:number,data:unknown[]}}>('select appointments_day($1) as data',[day])).rows[0].data;
  expect(data.total).toBe(2);expect(data.data).toHaveLength(2);
  expect((await db.query<{data:unknown}>('select appointment_details($1) as data',['ffffffff-ffff-4fff-8fff-ffffffffffff'])).rows[0].data).toBeNull();
});
test('competing requests for a free slot create only one booking',async()=>{
  const later=new Date(new Date(start).getTime()+5*3600000).toISOString();
  const results=await Promise.allSettled([create('10000000-0000-4000-8000-000000000006',later,25000),create('10000000-0000-4000-8000-000000000007',later,25000)]);
  expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);expect(results.filter(r=>r.status==='rejected')).toHaveLength(1);
});
test('ADMIN archive preserves snapshot records and hides archived details',async()=>{
  await asUser(admin);await db.query("select change_appointment($1,3,'ARCHIVE')",[appointment]);
  expect((await db.query<{data:unknown}>('select appointment_details($1) as data',[appointment])).rows[0].data).toBeNull();
  expect((await db.query('select * from appointment_services where appointment_id=$1',[appointment])).rows).toHaveLength(1);
});
