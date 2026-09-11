import { expect, test } from 'vitest';
import { bookingFingerprint, planWebsiteBooking, websiteBookingEvent } from '../src/lib/integrations/website-booking';

const event = {
  provider: 'elmaclinic.ma', event_id: 'event-1', booking_id: 'booking-1',
  occurred_at: '2030-01-01T09:00:00Z', source: 'WEBSITE',
  starts_at: '2030-01-02T10:00:00Z',
  client: { external_id: 'client-1', full_name: 'Cliente test', phone: null, email: null },
  practitioner_external_id: null, service_external_ids: ['service-b', 'service-a'], notes: null,
};

test('normalizes equivalent instants, object key order and service order for replay', () => {
  const reordered = { ...event, starts_at: '2030-01-02T11:00:00+01:00', service_external_ids: ['service-a', 'service-b'] };
  expect(bookingFingerprint(reordered)).toBe(bookingFingerprint(event));
  expect(bookingFingerprint(Object.fromEntries(Object.entries(event).reverse()))).toBe(bookingFingerprint(event));
});

test('rejects unknown sources and privilege or price overrides', () => {
  for (const extra of [{ source: 'APPLICATION' }, { source: 'MANUAL' }, { price_centimes: 1 }, { status: 'CONFIRMED' }, { role: 'ADMIN' }]) {
    expect(websiteBookingEvent.safeParse({ ...event, ...extra }).success).toBe(false);
  }
});

test('rejects ambiguous dates, repeated services and invalid external identifiers', () => {
  for (const extra of [{ starts_at: '2030-01-02T10:00:00' }, { event_id: ' event-1' }, { booking_id: 'a\nb' }, { service_external_ids: ['a', 'a'] }, { service_external_ids: [] }]) {
    expect(websiteBookingEvent.safeParse({ ...event, ...extra }).success).toBe(false);
  }
});

test('identical event returns its persisted result, including a pending receipt', () => {
  for (const appointmentId of ['appointment-1', null]) {
    expect(planWebsiteBooking(event, { fingerprint: bookingFingerprint(event), appointmentId }, null))
      .toEqual({ kind: 'REPLAY', appointmentId });
  }
});

test('same event ID with changed content is a conflict, not another booking', () => {
  expect(planWebsiteBooking({ ...event, notes: 'Changed' }, { fingerprint: bookingFingerprint(event), appointmentId: 'appointment-1' }, null))
    .toEqual({ kind: 'EVENT_ID_CONFLICT' });
});

test('older deliveries cannot overwrite newer website state', () => {
  expect(planWebsiteBooking(event, null, { externalUpdatedAt: '2030-01-01T10:00:00Z' })).toEqual({ kind: 'STALE' });
});

test('equal or newer updates require review rather than overwrite staff changes', () => {
  for (const externalUpdatedAt of ['2030-01-01T09:00:00Z', '2029-12-31T09:00:00Z']) {
    expect(planWebsiteBooking(event, null, { externalUpdatedAt })).toEqual({ kind: 'REVIEW_UPDATE' });
  }
});

test('unseen valid event is planned as a new booking without writing data', () => {
  expect(planWebsiteBooking(event, null, null)).toEqual({ kind: 'NEW_BOOKING' });
});
