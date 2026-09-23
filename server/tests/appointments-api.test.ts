import { beforeEach,expect,test,vi } from 'vitest';
const mocks=vi.hoisted(()=>({authenticate:vi.fn(),rpc:vi.fn()}));
vi.mock('../src/lib/auth',async()=>({...await vi.importActual<typeof import('../src/lib/auth')>('../src/lib/auth'),authenticate:mocks.authenticate}));
import { POST,GET } from '../src/app/api/v1/appointments/route';
import { PATCH,DELETE } from '../src/app/api/v1/appointments/[id]/route';
import { HttpError } from '../src/lib/http';
const id='00000000-0000-4000-8000-000000000001';
const body={client_id:id,practitioner_id:id,service_ids:[id],starts_at:'2030-01-01T10:00:00Z',request_id:id,expected_total_centimes:20000,expected_duration_minutes:30};
const request=(data:unknown)=>new Request('http://localhost/api',{method:'POST',body:JSON.stringify(data)});
beforeEach(()=>{mocks.rpc.mockReset().mockResolvedValue({data:id,error:null});mocks.authenticate.mockReset().mockResolvedValue({user:{role:'USER'},db:{rpc:mocks.rpc}});});
test('staff create uses guarded command, server-assigned source and confirmed quote',async()=>{
  for(const extra of [{source:'APPLICATION'},{source:'WEBSITE'},{price_centimes:1}]) expect((await POST(request({...body,...extra}))).status).toBe(422);
  expect(mocks.rpc).not.toHaveBeenCalled();
  expect((await POST(request(body))).status).toBe(201);
  expect(mocks.rpc).toHaveBeenCalledWith('create_manual_appointment',expect.objectContaining({expected_total:20000,expected_duration:30,request_key:id}));
});
test('unauthenticated reads and USER archival return 401/403 before database access',async()=>{
  expect((await DELETE(request({version:1}),{params:Promise.resolve({id:'ignored'})})).status).toBe(403);
  mocks.authenticate.mockRejectedValue(new HttpError(401,'Session invalide.'));
  expect((await GET(new Request('http://localhost/api?date=2030-01-01'))).status).toBe(401);expect(mocks.rpc).not.toHaveBeenCalled();
});
test('stale/conflicting changes return 409 and reject edits to snapshot/source fields',async()=>{
  expect((await PATCH(request({action:'STATUS',version:1,status:'CONFIRMED',source:'MANUAL'}),{params:Promise.resolve({id})})).status).toBe(422);
  mocks.rpc.mockResolvedValue({data:null,error:{code:'23505',message:'Le rendez-vous a été modifié. Actualisez la fiche.'}});
  expect((await PATCH(request({action:'STATUS',version:1,status:'CONFIRMED'}),{params:Promise.resolve({id})})).status).toBe(409);
});
test('total override uses a guarded RPC and rejects malformed fields',async()=>{
  expect((await PATCH(request({action:'TOTAL',version:1,total_centimes:15000}),{params:Promise.resolve({id})})).status).toBe(200);
  expect(mocks.rpc).toHaveBeenCalledWith('update_appointment_total',{record_id:id,expected_version:1,total_centimes:15000});
  expect((await PATCH(request({action:'TOTAL',version:1,total_centimes:-1}),{params:Promise.resolve({id})})).status).toBe(422);
});
