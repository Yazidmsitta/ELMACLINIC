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




const items=()=>JSON.stringify([{service_id:service,sessions:6}]);
async function save(id:string|null=null,version=0,price=120000){return db.query<{save_pack:string}>('select save_pack($1,$2,$3,$4,$5,$6,$7)',[id,'Pack laser','Six séances',price,true,version,items()]);}
test('pack writes are ADMIN-only and direct writes remain forbidden',async()=>{
 await asUser();await expect(save()).rejects.toThrow();
 await expect(db.exec("insert into packs(name,price_centimes) values('Bypass',1)")).rejects.toThrow();
});
test('repeated sessions keep an independent price and stale edits fail',async()=>{
 await asUser(admin);const id=(await save()).rows[0].save_pack;
 expect((await db.query<{sessions:number}>('select sessions from pack_items where pack_id=$1',[id])).rows[0].sessions).toBe(6);
 await save(id,1,110000);await expect(save(id,1)).rejects.toThrow('Actualisez');
 await asUser();expect((await db.query<{price_centimes:number}>('select price_centimes from packs where id=$1',[id])).rows[0].price_centimes).toBe(110000);
});
test('mixed prestations validate duplicate components and preserve existing pack on invalid save',async()=>{
 await asUser(admin);const second=(await db.query<{id:string}>("insert into services(name,duration_minutes,price_centimes) values('Visage',45,30000) returning id")).rows[0].id;
 const mixed=JSON.stringify([{service_id:service,sessions:3},{service_id:second,sessions:2}]);
 const id=(await db.query<{save_pack:string}>('select save_pack(null,$1,null,50000,true,0,$2)',['Mixte',mixed])).rows[0].save_pack;
 expect((await db.query('select * from pack_items where pack_id=$1',[id])).rows).toHaveLength(2);
 await expect(db.query('select save_pack($1,$2,null,1,true,1,$3)',[id,'Invalid',JSON.stringify([{service_id:service,sessions:1},{service_id:service,sessions:2}])])).rejects.toThrow();
 expect((await db.query('select * from pack_items where pack_id=$1',[id])).rows).toHaveLength(2);
});
