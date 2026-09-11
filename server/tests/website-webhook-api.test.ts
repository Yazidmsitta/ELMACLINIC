import { createHmac } from 'node:crypto';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ rpc: vi.fn(), privileged: vi.fn() }));
vi.mock('../src/lib/supabase', () => ({ privilegedDatabase: mocks.privileged }));
import { POST } from '../src/app/api/v1/integrations/website-bookings/route';
const key = 'ab'.repeat(32);
const id = '00000000-0000-4000-8000-000000000001';
const event = { provider:'elmaclinic.ma',event_id:'event-1',booking_id:'booking-1',source:'WEBSITE',
  occurred_at:'2030-01-01T10:00:00Z',starts_at:'2030-01-02T10:00:00Z',
  client:{external_id:'client-1',full_name:'Test',phone:null,email:null},practitioner_external_id:null,service_external_ids:['s1'],notes:null };
function request(payload:unknown=event, signingKey=key) {
  const body=JSON.stringify(payload), timestamp=String(Math.floor(Date.now()/1000));
  return new Request('https://example.test/api/v1/integrations/website-bookings',{method:'POST',body,headers:{
    'content-type':'application/json','x-elma-timestamp':timestamp,
    'x-elma-signature':`sha256=${createHmac('sha256',Buffer.from(signingKey,'hex')).update(`${timestamp}.${body}`).digest('hex')}`,
  }});
}
beforeEach(()=>{
  vi.stubEnv('WEBSITE_WEBHOOK_ENABLED','true');vi.stubEnv('WEBSITE_WEBHOOK_SECRET_HEX',key);vi.stubEnv('RATE_LIMIT_SECRET','test'.repeat(10));
  mocks.privileged.mockReset().mockReturnValue({rpc:mocks.rpc});
  mocks.rpc.mockReset().mockImplementation(async(name:string)=>name==='consume_auth_limit'?{data:true,error:null}:{data:{id,state:'REVIEW',appointment_id:null,replayed:false},error:null});
});
afterEach(()=>vi.unstubAllEnvs());
test('disabled and misconfigured receivers fail closed before database access',async()=>{
  vi.stubEnv('WEBSITE_WEBHOOK_ENABLED','false');expect((await POST(request())).status).toBe(503);
  vi.stubEnv('WEBSITE_WEBHOOK_ENABLED','true');vi.stubEnv('WEBSITE_WEBHOOK_SECRET_HEX','bad');expect((await POST(request())).status).toBe(503);
  expect(mocks.privileged).not.toHaveBeenCalled();
});
test('invalid signature or payload cannot reach privileged storage',async()=>{
  expect((await POST(request(event,'cd'.repeat(32)))).status).toBe(401);
  expect((await POST(request({...event,source:'MANUAL'}))).status).toBe(400);
  expect(mocks.privileged).not.toHaveBeenCalled();
});
test('valid delivery is normalized and acknowledged only after durable receipt',async()=>{
  const response=await POST(request());expect(response.status).toBe(202);
  expect(response.headers.get('cache-control')).toBe('no-store');
  expect(mocks.rpc).toHaveBeenLastCalledWith('receive_website_booking',{event_payload:expect.objectContaining({source:'WEBSITE',starts_at:'2030-01-02T10:00:00.000Z'})});
  expect(await response.json()).toEqual({id,state:'REVIEW',appointment_id:null,replayed:false});
});
test('throttling and storage outages never acknowledge an event',async()=>{
  mocks.rpc.mockResolvedValueOnce({data:false,error:null});const limited=await POST(request());
  expect(limited.status).toBe(429);expect(limited.headers.get('retry-after')).toBe('60');expect(mocks.rpc).toHaveBeenCalledTimes(1);
  mocks.rpc.mockResolvedValueOnce({data:true,error:null}).mockResolvedValueOnce({data:null,error:{code:'08006'}});
  expect((await POST(request())).status).toBe(503);
});
test('replays return 200, ID conflicts 409 and malformed receipts 503',async()=>{
  for(const [result,status] of [
    [{data:{id,state:'IMPORTED',appointment_id:id,replayed:true},error:null},200],
    [{data:null,error:{code:'23505'}},409],
    [{data:{},error:null},503],
  ] as const){
    mocks.rpc.mockResolvedValueOnce({data:true,error:null}).mockResolvedValueOnce(result);
    expect((await POST(request())).status).toBe(status);
  }
});
