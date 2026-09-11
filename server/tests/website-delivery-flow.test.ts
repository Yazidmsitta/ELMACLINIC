import { beforeAll,afterAll,expect,test,vi } from 'vitest';
import { createHmac } from 'node:crypto';
const transport=vi.hoisted(()=>({rpc:vi.fn()}));
vi.mock('../src/lib/supabase',()=>({privilegedDatabase:()=>({rpc:transport.rpc})}));
import { POST } from '../src/app/api/v1/integrations/website-bookings/route';
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
afterAll(async()=>{vi.unstubAllEnvs();await db.close();});


const key='ef'.repeat(32); // Local fixture only.
let receiptId:string;
function event(id='flow-event',bookingId='flow-booking') {
 return {provider:'elmaclinic.ma',event_id:id,booking_id:bookingId,source:'WEBSITE',
  occurred_at:'2026-01-01T10:00:00Z',starts_at:new Date(start).toISOString(),
  client:{external_id:'website-client',full_name:'Client test',phone:null,email:null},
  practitioner_external_id:'website-practitioner',service_external_ids:['website-service'],notes:null};
}
function signed(payload:unknown,secret=key){
 const timestamp=String(Math.floor(Date.now()/1000));const body=JSON.stringify(payload);
 return new Request('https://example.test/api/v1/integrations/website-bookings',{method:'POST',body,headers:{
  'content-type':'application/json','x-elma-timestamp':timestamp,
  'x-elma-signature':`sha256=${createHmac('sha256',Buffer.from(secret,'hex')).update(`${timestamp}.${body}`).digest('hex')}`,
 }});
}
function connectTransport(){
 vi.stubEnv('WEBSITE_WEBHOOK_ENABLED','true');vi.stubEnv('WEBSITE_WEBHOOK_SECRET_HEX',key);vi.stubEnv('RATE_LIMIT_SECRET','fixture'.repeat(8));
 // Only the Supabase RPC transport is substituted. The handler, signature
 // validation, rate limit and receipt SQL execute their production code.
 transport.rpc.mockImplementation(async(name:string,args:Record<string,unknown>)=>{
  await db.exec('reset role; set role service_role');
  try{
   const result=name==='consume_auth_limit'
    ? await db.query<{data:unknown}>('select consume_auth_limit($1,$2) as data',[args.bucket_key,args.maximum])
    : await db.query<{data:unknown}>('select receive_website_booking($1) as data',[JSON.stringify(args.event_payload)]);
   return {data:result.rows[0].data,error:null};
  }catch(error){return {data:null,error:{code:(error as {code:string}).code}};}
 });
}
test('signed delivery reaches PostgreSQL review, staff imports, replay returns saved appointment',async()=>{
 connectTransport();
 const delivery=await POST(signed(event()));expect(delivery.status).toBe(202);
 const receipt=await delivery.json();receiptId=receipt.id;expect(receipt.state).toBe('REVIEW');
 await asUser();
 expect((await db.query('select * from website_booking_events where id=$1',[receiptId])).rows).toHaveLength(1);
 appointment=(await db.query<{id:string}>('select import_website_booking($1,1,$2,$3,$4,20000,30) as id',[receiptId,client,practitioner,[service]])).rows[0].id;
 const details=(await db.query<{data:{source:string,total_centimes:number}}>('select appointment_details($1) as data',[appointment])).rows[0].data;
 expect(details.source).toBe('WEBSITE');expect(details.total_centimes).toBe(20000);
 const replay=await POST(signed(event()));expect(replay.status).toBe(200);
 expect(await replay.json()).toEqual({id:receiptId,state:'IMPORTED',appointment_id:appointment,replayed:true});
 await db.exec('reset role');
 expect((await db.query('select * from appointments')).rows).toHaveLength(1);
 expect((await db.query('select * from notifications where appointment_id=$1',[appointment])).rows).toHaveLength(2);
});
test('tampered delivery creates nothing and reused event ID cannot overwrite persisted data',async()=>{
 const before=transport.rpc.mock.calls.length;
 expect((await POST(signed(event('tampered'),'ab'.repeat(32)))).status).toBe(401);
 expect(transport.rpc.mock.calls.length).toBe(before);
 expect((await POST(signed({...event(),notes:'Changed'}))).status).toBe(409);
 await db.exec('reset role');
 expect((await db.query('select * from website_booking_events')).rows).toHaveLength(1);
 expect((await db.query<{payload:{notes:null}}>('select payload from website_booking_events where id=$1',[receiptId])).rows[0].payload.notes).toBeNull();
});
test('signed request persists despite occupied slot, failed staff import remains reviewable',async()=>{
 const response=await POST(signed(event('conflict-event','conflict-booking')));expect(response.status).toBe(202);
 const receipt=await response.json();await asUser();
 await expect(db.query('select import_website_booking($1,1,$2,$3,$4,20000,30) as id',[receipt.id,client,practitioner,[service]])).rejects.toThrow('déjà réservé');
 const replay=await POST(signed(event('conflict-event','conflict-booking')));
 expect(await replay.json()).toEqual({id:receipt.id,state:'REVIEW',appointment_id:null,replayed:true});
 await db.exec('reset role');expect((await db.query('select * from appointments')).rows).toHaveLength(1);
});
