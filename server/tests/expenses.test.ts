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

test('financial report denies USER and reports empty periods without invented profit',async()=>{
 await asUser();await expect(db.query("select financial_report('2000-01-01','2000-01-31')")).rejects.toThrow();
 await asUser(admin);
 const report=(await db.query<{value:Record<string,unknown>}>("select financial_report('2000-01-01','2000-01-31') as value")).rows[0].value;
 expect(report).toMatchObject({received_centimes:0,expense_centimes:0,cash_balance_centimes:0,currency:'MAD'});
 expect(report).not.toHaveProperty('profit');
 await expect(db.query("select financial_report('2000-01-31','2000-01-01')")).rejects.toThrow();
 await expect(db.query("select financial_report('2000-01-01','2002-01-01')")).rejects.toThrow();
 await asUser();
});

test('expense summary is ADMIN-only and includes all active accounting dates in the clinic month',async()=>{
 await asUser();
 await expect(db.query('select expense_summary()')).rejects.toThrow();
 await db.exec('reset role');
 await db.exec(`insert into expenses(description,category,amount_centimes,spent_on,recorded_by)
   select 'Summary fixture','Test',123,(date_trunc('month',now() at time zone 'Africa/Casablanca'))::date,'${admin}'
   from generate_series(1,51);
   insert into expenses(description,category,amount_centimes,spent_on,recorded_by,voided_at)
   values ('Summary fixture','Test',999,(now() at time zone 'Africa/Casablanca')::date,'${admin}',now());
   insert into expenses(description,category,amount_centimes,spent_on,recorded_by)
   values ('Summary fixture','Test',999,(date_trunc('month',now() at time zone 'Africa/Casablanca')+interval '1 month')::date,'${admin}'),
   ('Summary fixture','Test',999,date_trunc('month',now() at time zone 'Africa/Casablanca')::date-1,'${admin}');`);
 await asUser(admin);
 const summary=(await db.query<{value:{month_centimes:number,month_transactions:number,currency:string}}>('select expense_summary() as value')).rows[0].value;
 expect(summary).toMatchObject({month_centimes:6273,month_transactions:51,currency:'MAD'});
 await db.exec("reset role;delete from expenses where description='Summary fixture';");
 await asUser();
});

const key='10000000-0000-4000-8000-000000000099';let expense:string;
async function save(amount=10000,id:string|null=null,version:number|null=null){return db.query<{id:string}>("select save_expense('Loyer','Locaux',$1,'2026-09-01',$2,$3,$4) as id",[amount,key,id,version]);}
test('USER cannot create, edit, void or read expenses',async()=>{
 await expect(save()).rejects.toThrow();await expect(db.query("select void_expense($1,1,'Motif')",[admin])).rejects.toThrow();
 expect((await db.query('select * from expenses')).rows).toHaveLength(0);
});
test('ADMIN creation is idempotent and update preserves recorder with version protection',async()=>{
 await asUser(admin);expense=(await save()).rows[0].id;expect((await save()).rows[0].id).toBe(expense);
 await expect(save(999)).rejects.toThrow('Clé');await save(12000,expense,1);
 await expect(save(13000,expense,1)).rejects.toThrow('Actualisez');
 const row=(await db.query<{amount_centimes:number,recorded_by:string}>('select * from expenses where id=$1',[expense])).rows[0];
 expect(row.amount_centimes).toBe(12000);expect(row.recorded_by).toBe(admin);
 await expect(db.query('update expenses set amount_centimes=1')).rejects.toThrow(/permission denied/);
});
test('void requires reason and retains historical expense; no subsequent edits',async()=>{
 await expect(db.query('select void_expense($1,2,$2)',[expense,' '])).rejects.toThrow();
 await db.query('select void_expense($1,2,$2)',[expense,'Saisie en double']);
 const row=(await db.query<{voided_at:string,void_reason:string,version:number}>('select * from expenses where id=$1',[expense])).rows[0];
 expect(row.voided_at).toBeTruthy();expect(row.void_reason).toBe('Saisie en double');expect(row.version).toBe(3);
 await expect(save(14000,expense,3)).rejects.toThrow('annulée');
 expect((await db.query("select * from activity_logs where entity_type='expenses' and entity_id=$1",[expense])).rows).toHaveLength(3);
 await asUser();expect((await db.query('select * from expenses')).rows).toHaveLength(0);
});
