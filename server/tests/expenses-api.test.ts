import { beforeEach,expect,test,vi } from 'vitest';
const mocks=vi.hoisted(()=>({authenticate:vi.fn(),rpc:vi.fn()}));
vi.mock('../src/lib/auth',async()=>({...await vi.importActual<typeof import('../src/lib/auth')>('../src/lib/auth'),authenticate:mocks.authenticate}));
import { GET,POST } from '../src/app/api/v1/expenses/route';
import { PATCH,DELETE } from '../src/app/api/v1/expenses/[id]/route';
import { GET as SUMMARY } from '../src/app/api/v1/expenses/summary/route';
const id='00000000-0000-4000-8000-000000000001';
const body={description:'Loyer',category:'Locaux',amount_centimes:10000,spent_on:'2026-09-01',request_id:id};
const request=(data:unknown)=>new Request('http://localhost/api',{method:'POST',body:JSON.stringify(data)});
const context={params:Promise.resolve({id})};
beforeEach(()=>{mocks.rpc.mockReset().mockResolvedValue({data:id,error:null});mocks.authenticate.mockReset().mockResolvedValue({user:{role:'USER'},db:{rpc:mocks.rpc}});});

test('summary denies USER and returns database aggregate to ADMIN',async()=>{
 expect((await SUMMARY(request({}))).status).toBe(403);
 expect(mocks.rpc).not.toHaveBeenCalled();
 mocks.authenticate.mockResolvedValue({user:{role:'ADMIN'},db:{rpc:mocks.rpc}});
 const summary={currency:'MAD',clinic_date:'2026-09-11',month_centimes:6273,month_transactions:51};
 mocks.rpc.mockResolvedValue({data:summary,error:null});
 const response=await SUMMARY(request({}));
 expect(response.status).toBe(200);expect(await response.json()).toEqual(summary);
 expect(mocks.rpc).toHaveBeenCalledWith('expense_summary');
});
test('USER expense reads and all mutations return 403 before database access',async()=>{
 for(const response of [await GET(request({})),await POST(request(body)),await PATCH(request({}),context),await DELETE(request({}),context)])expect(response.status).toBe(403);
 expect(mocks.rpc).not.toHaveBeenCalled();
});
test('ADMIN validation rejects overrides and stale database conflicts return 409',async()=>{
 mocks.authenticate.mockResolvedValue({user:{role:'ADMIN'},db:{rpc:mocks.rpc}});
 expect((await POST(request({...body,recorded_by:id}))).status).toBe(422);
 expect((await POST(request(body))).status).toBe(201);
 mocks.rpc.mockResolvedValue({data:null,error:{code:'23505'}});
 expect((await DELETE(request({version:1,reason:'Doublon'}),context)).status).toBe(409);
});
