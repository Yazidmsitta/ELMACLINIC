import { beforeEach, expect, test, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ database: vi.fn(), privilegedDatabase: vi.fn() }));
vi.mock('../src/lib/supabase', () => mocks);
import { authenticate } from '../src/lib/auth';
const request = new Request('http://localhost/api', { headers: { authorization: 'Bearer token' } });
beforeEach(() => { vi.resetAllMocks(); });
test('role comes from active database profile, not auth metadata', async () => {
  const single = vi.fn().mockResolvedValue({ data: { id: 'uuid', full_name: 'Staff', role: 'USER', active: true } });
  const getUser = vi.fn().mockResolvedValue({ data: { user: { id: 'uuid', email: 'staff@example.test', user_metadata: { role: 'ADMIN' } } } });
  mocks.database.mockReturnValue({ auth: { getUser }, from: () => ({ select: () => ({ eq: () => ({ single }) }) }) });
  expect((await authenticate(request)).user.role).toBe('USER');
  expect(mocks.database).toHaveBeenCalledWith('token');
  expect(getUser).toHaveBeenCalledWith('token');
});
test('disabled or missing profile is forbidden', async () => {
  mocks.database.mockReturnValue({ auth: { getUser: async () => ({ data: { user: { id: 'uuid' } } }) }, from: () => ({ select: () => ({ eq: () => ({ single: async () => ({ data: null, error: { code: 'PGRST116' } }) }) }) }) });
  await expect(authenticate(request)).rejects.toMatchObject({ status: 403 });
});
test('invalid token is unauthorized; provider outage is not mistaken for invalid credentials', async () => {
  for (const status of [401, 503]) {
    mocks.database.mockReturnValue({ auth: { getUser: async () => ({ data: { user: null }, error: { status } }) } });
    await expect(authenticate(request)).rejects.toMatchObject({ status });
  }
});
