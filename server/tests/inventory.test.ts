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


let product:string;
const key='10000000-0000-4000-8000-000000000123';
async function adjust(quantity:string, request=key) { return db.query<{id:string}>('select adjust_inventory($1,$2,$3,$4) as id',[product,quantity,'Réception stock',request]); }
test('inventory adjustments enforce ADMIN and preserve exact idempotent movements',async()=>{
 await db.exec('reset role');
 product=(await db.query<{id:string}>("insert into products(sku,name,unit,cost_centimes) values('TEST','Produit','ml',100) returning id")).rows[0].id;
 await asUser();await expect(adjust('1.125')).rejects.toThrow();
 expect((await db.query('select * from inventory_transactions')).rows).toHaveLength(0);
 await asUser(admin);
 const first=(await adjust('1.125')).rows[0].id;
 expect((await adjust('1.125')).rows[0].id).toBe(first);
 await expect(adjust('2')).rejects.toThrow('Clé');
 expect((await db.query('select * from inventory_transactions')).rows).toHaveLength(1);
 await expect(db.query('delete from inventory_transactions')).rejects.toThrow(/permission denied/);
});
test('stock cannot become negative and invalid precision is rejected',async()=>{
 for (const value of ['0','0.0001','NaN','Infinity','1000000000']) await expect(adjust(value)).rejects.toThrow();
 await expect(adjust('-2','10000000-0000-4000-8000-000000000124')).rejects.toThrow('Stock');
 await adjust('-0.125','10000000-0000-4000-8000-000000000125');
 expect((await db.query<{balance:string}>('select sum(quantity)::text as balance from inventory_transactions')).rows[0].balance).toBe('1.000');
 expect((await db.query("select * from activity_logs where entity_type='inventory_transactions'")).rows).toHaveLength(2);
});
test('inactive products reject new movements but original retries stay safe',async()=>{
 await db.exec('reset role');await db.query('update products set active=false where id=$1',[product]);await asUser(admin);
 await expect(adjust('1','10000000-0000-4000-8000-000000000126')).rejects.toThrow('inactif');
 expect((await adjust('1.125')).rows[0].id).toBeTruthy();
});

test('inventory reads preserve balances and exclude USER',async()=>{
 const list=(await db.query<{value:{data:Array<{quantity:string,version:number}>}}>('select inventory_list() as value')).rows[0].value;
 expect(list.data[0]).toMatchObject({quantity:'1.000',version:1});
 const history=(await db.query<{value:{quantity:string,total:number,data:unknown[]}}>('select inventory_history($1,2) as value',[product])).rows[0].value;
 expect(history.quantity).toBe('1.000');expect(history.total).toBe(2);expect(history.data).toHaveLength(0);
 await asUser();await expect(db.query('select inventory_list()')).rejects.toThrow();
 await expect(db.query('select inventory_history($1)',[product])).rejects.toThrow();await asUser(admin);
});

test('product changes protect units and stale versions; create and update are audited',async()=>{
 const save=(unit='ml',version=1)=>db.query('select save_product($1,$2,$3,100,2,true,$4,$5)',['TEST','Updated product',unit,product,version]);
 await expect(save('litre')).rejects.toThrow('Unité');
 await save();await expect(save()).rejects.toThrow('modifié');
 const created=(await db.query<{id:string}>("select save_product('NEW','New product','unité',200,0,true) as id")).rows[0].id;
 expect(created).toBeTruthy();
 expect((await db.query("select * from activity_logs where entity_type='products'")).rows).toHaveLength(2);
 await asUser();await expect(save('ml',2)).rejects.toThrow();await asUser(admin);
});

test('website projection is service-only and excludes private practitioner fields',async()=>{
 await asUser(admin);await expect(db.query('select website_catalog()')).rejects.toThrow();
 await db.exec('reset role;set role service_role');
 const result=(await db.query<{value:{practitioners:Array<Record<string,unknown>>,services:unknown[]}}>('select website_catalog() as value')).rows[0].value;
 expect(result.services).toHaveLength(1);
 expect(Object.keys(result.practitioners[0]).sort()).toEqual(['full_name','id','specialty']);
 await asUser(admin);
});
