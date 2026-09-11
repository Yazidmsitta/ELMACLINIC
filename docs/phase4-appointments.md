# Phase 4 — appointments

Implemented locally on 10 September 2026. This continues the approved Flutter → Next.js → Supabase architecture and preserves the earlier phases and archives.

## Staff workflow

Both roles can browse a real clinic day, move between weeks, select a calendar date, filter by status/source/practitioner, inspect a specific appointment, create a manual appointment, reschedule an eligible appointment and apply allowed status transitions. ADMIN alone can archive an appointment. Missing details show an error rather than a different record.

The five-step creation flow follows the inspected Figma source: Client → Prestation → Praticienne → Date & heure → Confirmation. It supports searching/paging through real records, creating a basic client, selecting up to ten distinct services, category/subcategory filtering, clinic-local date/time selection and optional notes. The confirmation displays a server-generated quote. The dashboard’s new-booking and appointment-card actions now open these flows, and returning to Home refreshes its counters.

Every manual booking starts as CONFIRMED with source MANUAL. Staff cannot submit a source, end time, price override or service snapshot. Existing WEBSITE appointments retain their source when rescheduled or cancelled. No website endpoint or imported appointment is simulated; the provider integration remains Phase 5.

## Business rules and transactions

- A booking must use an existing non-archived client, active services and an active practitioner. Its start must be in the future.
- The server calculates duration and integer-centime totals. The whole appointment must fit within one configured weekly shift, on one Casablanca calendar day, and avoid absences and overlapping reserved appointments for that practitioner. Adjacent intervals are allowed.
- NEW, PENDING, CONFIRMED and IN_PROGRESS reserve their assigned practitioner’s time. CANCELLED, NO_SHOW and COMPLETED do not reserve new booking capacity.
- Creation locks the practitioner and relevant catalog/client records, rechecks availability, compares the reviewed total/duration, writes service snapshots and records the audit event in one transaction. A changed price or duration requires a new quote; it cannot silently change the confirmed amount.
- A UUID request key identifies each creation attempt. Repeating the same actor/key/payload returns the existing appointment; a different payload using that key returns 409. The Flutter draft reuses its key after a failed confirmation. Drafts and keys are not persisted across process restarts; the booking-conflict checks still apply to subsequent attempts.
- Changes require the version last read by the client. Stale versions return 409 and require a refresh. Rescheduling changes the practitioner, start and notes while preserving client, services, recorded duration, prices and source. Changing booked services/client is intentionally handled by cancellation and a new booking in this phase.
- Appointment commands share a transaction-level advisory lock; practitioner row locks also coordinate with availability edits. Migration 008 rejects schedule/absence replacements that would strand a reserved appointment that has not ended.
- Archive is ADMIN-only and soft: snapshot records and references remain. Direct authenticated table writes are not granted; business commands enforce roles, active sessions and validation themselves. Service-role integrations must use the same locking/validation contract in Phase 5.

Allowed transitions:

| Current | Next |
| --- | --- |
| NEW | PENDING, CONFIRMED, CANCELLED |
| PENDING | CONFIRMED, CANCELLED |
| CONFIRMED | IN_PROGRESS, CANCELLED, NO_SHOW |
| IN_PROGRESS | COMPLETED, CANCELLED |
| COMPLETED / CANCELLED / NO_SHOW | Terminal in this phase |

IN_PROGRESS and NO_SHOW cannot be set before the scheduled start. Audit entries include actor, command, previous version/status/start and resulting status/start. Payments, refunds, attendance corrections and reopening terminal appointments are not implemented here.

## API contract

All routes require a bearer token and return no-cache JSON. Invalid fields return 422; conflicts return 409; forbidden archival returns 403; missing details return 404.

| Route | Body/query and result |
| --- | --- |
| GET `/appointments` | Required `date=YYYY-MM-DD`; optional `page,status,source,practitioner_id`. Returns `{data,page,per_page:50,total,has_more}`. |
| GET `/appointments/{uuid}` | `{data}` with real client/practitioner names, phone, source/status, timestamps, notes, version, service snapshots and total. |
| POST `/appointments/quote` | `{client_id,practitioner_id,service_ids,starts_at}` → `{data:{starts_at,ends_at,duration_minutes,total_centimes,services}}`. A quote does not reserve a slot. |
| POST `/appointments` | Selection fields plus `request_id,expected_total_centimes,expected_duration_minutes` and optional `notes` → HTTP 201 `{id}`. |
| PATCH `/appointments/{uuid}` | `{action:"STATUS",version,status}` or `{action:"RESCHEDULE",version,practitioner_id,starts_at,notes}` → `{id}`. |
| DELETE `/appointments/{uuid}` | ADMIN `{version}` → archival message. |

Timestamps are ISO 8601 instants with offsets; Flutter sends UTC. Day queries compute midnight boundaries in Africa/Casablanca, rather than adding a fixed 24 hours. UI date conversion uses the bundled IANA zone. Nonexistent and ambiguous clock-change wall times are rejected in the booking picker rather than silently choosing an instant.

## Design and verification

Re-inspected the saved Figma Make `Appointments.tsx`, `AppointmentDetail.tsx` and `NewAppointment.tsx` from the connected ElmaClinic design. The port uses the original theme/fonts/icons, day strip, status/source indicators, bordered cards, five progress segments, selection states and confirmation summary. Prototype dates, visits, phone numbers and payment success are not copied into production data. No phone/SMS or payment action claims success without its integration.

Four new 390×844 Flutter baselines cover the appointment day, filters, details and first booking step. A 320 px large-text/keyboard test verifies scrolling. The resulting screens were visually inspected; these are Flutter test renders, not Android screenshots or a pixel-diff against the Figma renderer.

Local verification: 36 server tests, 46 Flutter tests, 15 visual baselines overall, TypeScript checking and Next production build. PostgreSQL tests execute all eight migrations using explicit test Auth/Storage fixtures. They exercise authoritative prices, idempotency, occupied/free competing-slot requests, adjacent intervals, preserved snapshots/source, stale versions, lifecycle rules, archival and availability rollback. API tests cover 401/403/409/422 behavior. Flutter tests cover failed confirmation/retry, filtering, missing records, source rejection and clock changes.

The competing-request checks run against one PGlite engine. They do not replace a multi-connection PostgreSQL race/load test. The full Supabase Auth/PostgREST/Storage stack, Android device/emulator, APK build/signing and live deployment remain unverified here.

## Setup

After Phase 3, apply `202609090007_appointments.sql`, then `202609090008_availability_bookings.sql`. Do not reset an existing database. A practitioner needs a configured shift before manual booking is accepted. Run the commands in the README and verify a real ADMIN/USER booking, retry and conflicting booking against a development Supabase instance before staff use.
