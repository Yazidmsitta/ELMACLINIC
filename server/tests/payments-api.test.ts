import { beforeEach,expect,test,vi } from 'vitest';
const mocks=vi.hoisted(()=>({authenticate:vi.fn(),rpc:vi.fn()}));
vi.mock('../src/lib/auth',async()=>({...await vi.importActual<typeof import('../src/lib/auth')>('../src/lib/auth'),authenticate:mocks.authenticate}));
import { GET,POST } from '../src/app/api/v1/payments/route';
const id='00000000-0000-4000-8000-000000000001';
const body={appointment_id:id,amount_centimes:10000,method:'CASH',request_id:id};
const request=(data:unknown)=>new Request('http://localhost/api/v1/payments',{method:'POST',body:JSON.stringify(data)});
beforeEach(()=>{mocks.rpc.mockReset().mockResolvedValue({data:id,error:null});mocks.authenticate.mockReset().mockResolvedValue({user:{role:'USER'},db:{rpc:mocks.rpc}});});
test('USER can record payment but cannot read clinic ledger or inject currency/actor',async()=>{
 expect((await GET(new Request('http://localhost/api/v1/payments'))).status).toBe(403);
 for(const extra of [{currency:'EUR'},{recorded_by:id},{paid_at:'2030-01-01'}])expect((await POST(request({...body,...extra}))).status).toBe(422);
 expect(mocks.rpc).not.toHaveBeenCalled();
 expect((await POST(request(body))).status).toBe(201);
 expect(mocks.rpc).toHaveBeenCalledWith('record_payment',{appointment:id,amount:10000,payment_method:'CASH',request_key:id});
});
test('fractions, missing appointments and balance conflicts are explicit failures',async()=>{
 expect((await POST(request({...body,amount_centimes:1.5}))).status).toBe(422);
 mocks.rpc.mockResolvedValueOnce({data:null,error:null});expect((await POST(request(body))).status).toBe(404);
 mocks.rpc.mockResolvedValueOnce({data:null,error:{code:'23505'}});expect((await POST(request(body))).status).toBe(409);
});
