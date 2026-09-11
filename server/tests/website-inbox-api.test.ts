import { beforeEach, expect, test, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ authenticate: vi.fn(), rpc: vi.fn() }));
vi.mock('../src/lib/auth', () => ({ authenticate: mocks.authenticate }));
import { POST } from '../src/app/api/v1/website-bookings/[id]/import/route';
import { HttpError } from '../src/lib/http';
const id = '00000000-0000-4000-8000-000000000001';
const body = { version: 1, client_id: id, practitioner_id: id, service_ids: [id], expected_total_centimes: 20000, expected_duration_minutes: 30 };
const request = (data: unknown) => new Request('http://localhost/api', { method: 'POST', body: JSON.stringify(data) });
const context = { params: Promise.resolve({ id }) };
beforeEach(() => {
  mocks.rpc.mockReset().mockResolvedValue({ data: id, error: null });
  mocks.authenticate.mockReset().mockResolvedValue({ user: { role: 'USER' }, db: { rpc: mocks.rpc } });
});
test('USER import uses the guarded command and forbids source/status injection', async () => {
  expect((await POST(request({ ...body, source: 'MANUAL' }), context)).status).toBe(422);
  expect(mocks.rpc).not.toHaveBeenCalled();
  expect((await POST(request(body), context)).status).toBe(201);
  expect(mocks.rpc).toHaveBeenCalledWith('import_website_booking', expect.objectContaining({ event_record: id, expected_version: 1 }));
});
test('invalid authentication, missing records and conflicts retain HTTP semantics', async () => {
  mocks.authenticate.mockRejectedValueOnce(new HttpError(401, 'Session invalide.'));
  expect((await POST(request(body), context)).status).toBe(401);
  mocks.rpc.mockResolvedValueOnce({ data: null, error: null });
  expect((await POST(request(body), context)).status).toBe(404);
  mocks.rpc.mockResolvedValueOnce({ data: null, error: { code: '23505' } });
  expect((await POST(request(body), context)).status).toBe(409);
});
