import 'server-only';
import { createHash } from 'node:crypto';
import { z } from 'zod';

// Internal adapter output, NOT the elmaclinic.ma wire format. The future
// provider adapter must verify authenticity before passing events here.
const externalId = z.string().min(1).max(200).refine(value =>
  value === value.trim() && !/[\u0000-\u001f\u007f]/.test(value));
const instant = z.iso.datetime({ offset: true }).transform(value => new Date(value).toISOString());
export const websiteBookingEvent = z.object({
  provider: z.literal('elmaclinic.ma'),
  event_id: externalId,
  booking_id: externalId,
  occurred_at: instant,
  source: z.literal('WEBSITE'),
  starts_at: instant,
  client: z.object({
    external_id: externalId,
    full_name: z.string().trim().min(1).max(200),
    phone: z.string().trim().min(1).max(40).nullable(),
    email: z.email().max(254).nullable(),
  }).strict(),
  practitioner_external_id: externalId.nullable(),
  service_external_ids: z.array(externalId).min(1).max(10)
    .refine(ids => new Set(ids).size === ids.length)
    .transform(ids => [...ids].sort()),
  notes: z.string().trim().max(2000).nullable(),
}).strict();

export type WebsiteBookingEvent = z.output<typeof websiteBookingEvent>;

export interface BookingReceipt {
  readonly fingerprint: string;
  readonly appointmentId: string | null;
}

export interface ImportedBooking {
  readonly externalUpdatedAt: string;
}

export type IngestionDecision =
  | { readonly kind: 'REPLAY'; readonly appointmentId: string | null }
  | { readonly kind: 'EVENT_ID_CONFLICT' }
  | { readonly kind: 'STALE' }
  | { readonly kind: 'REVIEW_UPDATE' }
  | { readonly kind: 'NEW_BOOKING' };

/** A stable digest of validated adapter output; never log the input PII. */
export function bookingFingerprint(input: unknown): string {
  const event = websiteBookingEvent.parse(input);
  return createHash('sha256').update(JSON.stringify(event)).digest('hex');
}

/** Pure planning only. Receipt lookup and persistence must share a DB
 * transaction/unique constraints; this helper alone is not a concurrency lock.
 * Updates require review until the provider's ordering/ownership rules exist.
 */
export function planWebsiteBooking(
  input: unknown,
  receipt: BookingReceipt | null,
  existing: ImportedBooking | null,
): IngestionDecision {
  const event = websiteBookingEvent.parse(input);
  const fingerprint = bookingFingerprint(event);
  if (receipt) {
    return receipt.fingerprint === fingerprint
      ? { kind: 'REPLAY', appointmentId: receipt.appointmentId }
      : { kind: 'EVENT_ID_CONFLICT' };
  }
  if (existing) {
    const previous = z.iso.datetime({ offset: true }).parse(existing.externalUpdatedAt);
    return Date.parse(event.occurred_at) < Date.parse(previous)
      ? { kind: 'STALE' }
      : { kind: 'REVIEW_UPDATE' };
  }
  return { kind: 'NEW_BOOKING' };
}

export interface WebsiteBookingAdapter {
  // Implement against verified documentation, including request size limits,
  // signature/token verification and replay-window rules where applicable.
  authenticateAndDecode(request: Request): Promise<WebsiteBookingEvent>;
}
