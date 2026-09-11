import { beforeEach, expect, test, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ authenticate: vi.fn() }));
vi.mock('../src/lib/auth', async () => {
  const actual = await vi.importActual<typeof import('../src/lib/auth')>('../src/lib/auth');
  return { ...actual, authenticate: mocks.authenticate };
});
import { GET, POST } from '../src/app/api/v1/[resource]/route';
import { PATCH, DELETE } from '../src/app/api/v1/[resource]/[id]/route';
import { HttpError } from '../src/lib/http';
import { PUT as saveAvailability } from '../src/app/api/v1/practitioners/[id]/availability/route';
import { PUT as uploadImage } from '../src/app/api/v1/services/[id]/image/route';
beforeEach(() => { mocks.authenticate.mockReset(); mocks.authenticate.mockResolvedValue({ user: { role: 'USER' } }); });
test('USER admin API actions return HTTP 403 before any database operation', async () => {
  for (const resource of ['services','practitioners','users','expenses','settings','inventory','categories']) {
    expect((await POST(new Request('http://localhost/api'), { params: Promise.resolve({ resource }) })).status).toBe(403);
    expect((await PATCH(new Request('http://localhost/api'), { params: Promise.resolve({ resource, id: 'ignored' }) })).status).toBe(403);
  }
  for (const resource of ['payments','expenses','users','activity-logs','settings']) {
    expect((await GET(new Request('http://localhost/api'), { params: Promise.resolve({ resource }) })).status).toBe(403);
  }
  expect((await DELETE(new Request('http://localhost/api'), { params: Promise.resolve({ resource: 'clients', id: 'ignored' }) })).status).toBe(403);
  for (const action of [saveAvailability,uploadImage]) {
    expect((await action(new Request('http://localhost/api'), {params:Promise.resolve({id:'ignored'})})).status).toBe(403);
  }
});
test('unauthenticated requests return 401; deferred authorized commands return 501', async () => {
  mocks.authenticate.mockRejectedValueOnce(new HttpError(401,'Unauthenticated'));
  expect((await GET(new Request('http://localhost/api'), { params: Promise.resolve({ resource: 'clients' }) })).status).toBe(401);
  expect((await POST(new Request('http://localhost/api'), { params: Promise.resolve({ resource: 'payments' }) })).status).toBe(501);
  mocks.authenticate.mockResolvedValue({ user: { role: 'ADMIN' } });
  expect((await POST(new Request('http://localhost/api'), { params: Promise.resolve({ resource: 'users' }) })).status).toBe(501);
});
test('catalog create returns persisted row and rejects invalid fields before writing', async () => {
  const single = vi.fn().mockResolvedValue({data:{id:'persisted',name:'Soin'},error:null});
  const insert = vi.fn().mockReturnValue({select:vi.fn().mockReturnValue({single})});
  mocks.authenticate.mockResolvedValue({user:{role:'ADMIN'},db:{from:vi.fn().mockReturnValue({insert})}});
  const context = {params:Promise.resolve({resource:'services'})};
  const request = (body: unknown) => new Request('http://localhost/api',{method:'POST',body:JSON.stringify(body)});
  expect((await POST(request({name:'Soin',duration_minutes:30,price_centimes:20000,role:'ADMIN'}),context)).status).toBe(422);
  expect(insert).not.toHaveBeenCalled();
  const response = await POST(request({name:'Soin',duration_minutes:30,price_centimes:20000}),context);
  expect(response.status).toBe(201);
  expect(await response.json()).toEqual({data:{id:'persisted',name:'Soin'}});
  single.mockResolvedValue({data:null,error:{code:'42501'}});
  expect((await POST(request({name:'Soin',duration_minutes:30,price_centimes:20000}),context)).status).toBe(403);
});
