import { createHmac } from 'node:crypto';
import { expect, test } from 'vitest';
import { SignedWebsiteAdapter } from '../src/lib/integrations/signed-website-adapter';

const secret = 'ab'.repeat(32); // Test-only key.
const now = 1900000000;
const body = JSON.stringify({ provider: 'elmaclinic.ma', event_id: 'e1', booking_id: 'b1',
  occurred_at: '2030-01-01T09:00:00Z', source: 'WEBSITE', starts_at: '2030-01-02T09:00:00Z',
  client: { external_id: 'c1', full_name: 'Test', phone: null, email: null },
  practitioner_external_id: null, service_external_ids: ['s1'], notes: null });
const adapter = new SignedWebsiteAdapter(secret, () => now * 1000);
function request(raw = body, timestamp = now, signingKey = secret) {
  return new Request('https://example.test', { method: 'POST', body: raw, headers: {
    'content-type': 'application/json', 'x-elma-timestamp': String(timestamp),
    'x-elma-signature': `sha256=${createHmac('sha256', Buffer.from(signingKey, 'hex')).update(`${timestamp}.${raw}`).digest('hex')}`,
  } });
}
test('accepts a correctly signed v1 delivery', async () => {
  expect((await adapter.authenticateAndDecode(request())).booking_id).toBe('b1');
});
test('rejects tampering, wrong keys and missing authentication', async () => {
  const signed = request();
  const changed = new Request(signed.url, { method: 'POST', headers: signed.headers, body: body.replace('b1', 'b2') });
  for (const input of [changed, request(body, now, 'cd'.repeat(32)), new Request(signed.url, { method: 'POST', body })]) {
    await expect(adapter.authenticateAndDecode(input)).rejects.toMatchObject({ status: 401 });
  }
});
test('rejects expired and future timestamps outside the five minute window', async () => {
  for (const timestamp of [now - 301, now + 301]) await expect(adapter.authenticateAndDecode(request(body, timestamp))).rejects.toMatchObject({ status: 401 });
});
test('limits actual streamed bytes and validates signed JSON', async () => {
  await expect(adapter.authenticateAndDecode(request('x'.repeat(65537)))).rejects.toMatchObject({ status: 413 });
  await expect(adapter.authenticateAndDecode(request('{'))).rejects.toMatchObject({ status: 400 });
  await expect(adapter.authenticateAndDecode(request(body.replace('WEBSITE', 'APPLICATION')))).rejects.toMatchObject({ status: 400 });
});
test('rejects misconfigured keys at construction', () => {
  expect(() => new SignedWebsiteAdapter('short')).toThrow();
});
