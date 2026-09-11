import { beforeEach, expect, test, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ authenticate: vi.fn(), rpc: vi.fn() }));
vi.mock('../src/lib/auth', async () => ({ ...await vi.importActual<typeof import('../src/lib/auth')>('../src/lib/auth'), authenticate: mocks.authenticate }));
import { POST } from '../src/app/api/v1/inventory/adjustments/route';
const id = '00000000-0000-4000-8000-000000000001';
const body = { product_id: id, quantity: '1.125', reason: 'Réception', request_id: id };
const request = (data: unknown) => new Request('http://localhost/api', { method: 'POST', body: JSON.stringify(data) });
beforeEach(() => {
  mocks.rpc.mockReset().mockResolvedValue({ data: id, error: null });
  mocks.authenticate.mockReset().mockResolvedValue({ user: { role: 'ADMIN' }, db: { rpc: mocks.rpc } });
});
test('USER cannot adjust stock', async () => {
  mocks.authenticate.mockResolvedValue({ user: { role: 'USER' }, db: { rpc: mocks.rpc } });
  expect((await POST(request(body))).status).toBe(403);
  expect(mocks.rpc).not.toHaveBeenCalled();
});
test('quantity stays decimal text and invalid precision or recorder overrides fail', async () => {
  for (const quantity of [1.125, '0', '-0.000', '0.0001', 'NaN', '1e3']) {
    expect((await POST(request({ ...body, quantity }))).status).toBe(422);
  }
  expect((await POST(request({ ...body, recorded_by: id }))).status).toBe(422);
  expect((await POST(request(body))).status).toBe(201);
  expect(mocks.rpc).toHaveBeenCalledWith('adjust_inventory', { product: id, quantity_delta: '1.125', reason_text: 'Réception', request_key: id });
  mocks.rpc.mockResolvedValue({ data: null, error: null });
  expect((await POST(request(body))).status).toBe(404);
  mocks.rpc.mockResolvedValue({ data: null, error: { code: '23505' } });
  expect((await POST(request(body))).status).toBe(409);
});
