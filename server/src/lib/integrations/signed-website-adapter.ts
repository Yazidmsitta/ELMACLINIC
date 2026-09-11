import 'server-only';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { websiteBookingEvent, type WebsiteBookingAdapter, type WebsiteBookingEvent } from './website-booking';

export class WebsiteDeliveryError extends Error {
  constructor(readonly status: 400 | 401 | 413, message: string) { super(message); }
}

/** Proposed ElmaClinic webhook v1. Used by the opt-in receiver; the live website sender is not connected. */
export class SignedWebsiteAdapter implements WebsiteBookingAdapter {
  private readonly key: Buffer;
  constructor(secretHex: string, private readonly now: () => number = Date.now) {
    if (!/^[a-f0-9]{64}$/i.test(secretHex)) throw new Error('Webhook key must contain 32 random bytes encoded as hex.');
    this.key = Buffer.from(secretHex, 'hex');
  }

  async authenticateAndDecode(request: Request): Promise<WebsiteBookingEvent> {
    const timestamp = request.headers.get('x-elma-timestamp') ?? '';
    const signature = request.headers.get('x-elma-signature') ?? '';
    if (!/^\d{10}$/.test(timestamp) || !/^sha256=[a-f0-9]{64}$/i.test(signature)
      || Math.abs(Math.floor(this.now() / 1000) - Number(timestamp)) > 300) {
      throw new WebsiteDeliveryError(401, 'Signature invalide ou expirée.');
    }
    if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json'
      || (request.headers.has('content-encoding') && request.headers.get('content-encoding') !== 'identity')) {
      throw new WebsiteDeliveryError(400, 'JSON non compressé requis.');
    }
    const reader = request.body?.getReader();
    if (!reader) throw new WebsiteDeliveryError(400, 'Corps JSON requis.');
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 65536) {
          await reader.cancel();
          throw new WebsiteDeliveryError(413, 'Corps trop volumineux.');
        }
        chunks.push(value);
      }
    } finally { reader.releaseLock(); }
    const body = Buffer.concat(chunks);
    const expected = createHmac('sha256', this.key).update(`${timestamp}.`).update(body).digest();
    if (!timingSafeEqual(expected, Buffer.from(signature.slice(7), 'hex'))) {
      throw new WebsiteDeliveryError(401, 'Signature invalide ou expirée.');
    }
    try {
      return websiteBookingEvent.parse(JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(body)));
    } catch { throw new WebsiteDeliveryError(400, 'Événement invalide.'); }
  }
}
