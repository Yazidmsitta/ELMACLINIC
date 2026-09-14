import { beforeEach, expect, test, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ authenticate: vi.fn(), from: vi.fn(), select: vi.fn(), eq: vi.fn(), order: vi.fn(), range: vi.fn() }));
vi.mock('../src/lib/auth', async () => ({ ...await vi.importActual<typeof import('../src/lib/auth')>('../src/lib/auth'), authenticate: mocks.authenticate }));
import { GET } from '../src/app/api/v1/activity-logs/route';
beforeEach(() => {
  vi.clearAllMocks();
  for (const method of [mocks.from, mocks.select, mocks.eq, mocks.order]) method.mockReturnValue(mocks);
  mocks.range.mockResolvedValue({ data: [], count: 101, error: null });
  mocks.authenticate.mockResolvedValue({ user: { role: 'ADMIN' }, db: { from: mocks.from } });
});
test('USER cannot read audit records even with filters', async () => {
  mocks.authenticate.mockResolvedValue({ user: { role: 'USER' }, db: { from: mocks.from } });
  expect((await GET(new Request('http://localhost/api?entity_type=clients'))).status).toBe(403);
  expect(mocks.from).not.toHaveBeenCalled();
});
test('audit pagination and projection exclude metadata', async () => {
  const response = await GET(new Request('http://localhost/api?page=2&entity_type=clients'));
  expect(response.status).toBe(200);
  expect(mocks.select).toHaveBeenCalledWith('id,actor_id,action,entity_type,entity_id,created_at,actor:profiles!activity_logs_actor_id_fkey(full_name)', { count: 'exact' });
  expect(mocks.eq).toHaveBeenCalledWith('entity_type', 'clients');
  expect(mocks.range).toHaveBeenCalledWith(50, 99);
  expect(await response.json()).toMatchObject({ page: 2, has_more: true });
  for (const query of ['page=0', 'actor_id=invalid', 'entity_type=bad.value']) {
    expect((await GET(new Request(`http://localhost/api?${query}`))).status).toBe(422);
  }
});

test('author names are flattened without exposing the joined profile', async () => {
 mocks.range.mockResolvedValue({data:[{id:'entry',actor:{full_name:'Houda Benali'}}],count:1,error:null});
 const response=await GET(new Request('http://localhost/api'));
 expect((await response.json()).data).toEqual([{id:'entry',actor_name:'Houda Benali'}]);
});
