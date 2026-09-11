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
async function create(key:string,slot=start,amount=20000) {
  return db.query<{id:string}>('select create_manual_appointment($1,$2,$3,$4,$5,$6,$7,$8) as id',[client,practitioner,[service],slot,'Notes',key,amount,30]);
}

let payment:string;
const key='10000000-0000-4000-8000-000000000011';
async function pay(amount=10000,request=key,method='CASH'){
 return db.query<{id:string}>('select record_payment($1,$2,$3,$4) as id',[appointment,amount,method,request]);
}
test('USER records partial MAD payment and replay does not charge twice',async()=>{
 appointment=(await create('10000000-0000-4000-8000-000000000010')).rows[0].id;
 payment=(await pay()).rows[0].id;expect((await pay()).rows[0].id).toBe(payment);
 const balance=(await db.query<{data:unknown}>('select appointment_payment_balance($1) as data',[appointment])).rows[0].data;
 expect(balance).toEqual({appointment_id:appointment,currency:'MAD',total_centimes:20000,paid_centimes:10000,remaining_centimes:10000});
 expect((await db.query('select * from payments')).rows).toHaveLength(0);
 await expect(db.query('update payments set amount_centimes=1')).rejects.toThrow(/permission denied/);
});
test('same key cannot change payment details or leak another staff payment',async()=>{
 await expect(pay(5000)).rejects.toThrow('Clé de paiement');
 await asUser(admin);await expect(pay()).rejects.toThrow('Clé de paiement');await asUser();
});
test('invalid methods, nonpositive amounts and overpayment are rejected',async()=>{
 await expect(pay(0)).rejects.toThrow();await expect(pay(-1)).rejects.toThrow();
 await expect(pay(10000,key,'CRYPTO')).rejects.toThrow();
 await expect(pay(10001,'10000000-0000-4000-8000-000000000012')).rejects.toThrow('solde');
});
test('competing final payments cannot overpay and ADMIN sees the ledger',async()=>{
 const results=await Promise.allSettled([pay(10000,'10000000-0000-4000-8000-000000000013'),pay(10000,'10000000-0000-4000-8000-000000000014')]);
 expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
 await asUser(admin);expect((await db.query('select * from payments')).rows).toHaveLength(2);await asUser();
});
test('cancelled appointments reject new payment, but prior receipt remains replayable',async()=>{
 await db.query("select change_appointment($1,1,'STATUS',null,null,null,'CANCELLED')",[appointment]);
 await expect(pay(1,'10000000-0000-4000-8000-000000000015')).rejects.toThrow('Confirmez');
 expect((await pay()).rows[0].id).toBe(payment);
});

test('ADMIN ledger includes historical receipts and clinic totals; USER RPC is denied',async()=>{
 await asUser();await expect(db.query('select payment_ledger(1)')).rejects.toThrow();
 await asUser(admin);
 const ledger=(await db.query<{data:{total:number,today_centimes:number,month_centimes:number,data:{client_name:string}[]}}>('select payment_ledger(1) as data')).rows[0].data;
 expect(ledger.total).toBe(2);expect(ledger.today_centimes).toBe(20000);expect(ledger.month_centimes).toBe(20000);expect(ledger.data[0].client_name).toBe('Client');
 await db.query("select change_appointment($1,2,'ARCHIVE')",[appointment]);
 expect((await db.query<{data:{total:number}}>('select payment_ledger(1) as data')).rows[0].data.total).toBe(2);
 await asUser();
});
