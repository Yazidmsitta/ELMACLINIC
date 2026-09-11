# Phase 5 — proposed website contract, database review increment

10 September 2026. The user confirmed that the website booking API does not exist yet. This document proposes a **new contract** for its developer; it does not describe an existing elmaclinic.ma endpoint. An opt-in webhook receiver is implemented locally; no live website connection is delivered yet. The database review/import commands are now implemented.

## Implemented locally

The server-only integration module validates normalized website events, computes a canonical SHA-256 fingerprint and plans replay/conflict/stale/update handling. A signed adapter verifies HMAC-SHA256 over bounded raw request bytes before decoding the event. The signing adapter is exposed through the opt-in receiver documented below. Authenticated staff APIs now expose the review queue and explicit import command. No additional credentials are currently needed to run the application or tests.

## Proposed delivery format v1

The receiving path is `POST /api/v1/integrations/website-bookings` on the deployed HTTPS API host. The website should retain a durable outgoing event and retry delivery after temporary failures. For each attempt, set `Content-Type: application/json`, `X-Elma-Timestamp` to current Unix seconds and `X-Elma-Signature` to `sha256=<hex digest>`.

Compute HMAC-SHA256 using a dedicated shared 32-byte random key, stored as 64 hexadecimal characters in server-side secrets on both systems. Decode the hex key before signing. Sign the exact concatenation of ASCII timestamp, a period, and the raw UTF-8 JSON body. Do not reuse Supabase credentials. The body must be uncompressed and at most 65,536 bytes. Receiver and sender clocks must be synchronized; delivery timestamps outside ±300 seconds are rejected. Retried deliveries use a fresh timestamp/signature but preserve their event ID and contents. Key rotation and deployment secret names remain to be configured with the transport.

Example with synthetic values:

```json
{
  "provider": "elmaclinic.ma",
  "event_id": "booking-created-123",
  "booking_id": "123",
  "occurred_at": "2030-01-01T09:00:00Z",
  "source": "WEBSITE",
  "starts_at": "2030-01-02T10:00:00Z",
  "client": {
    "external_id": "client-456",
    "full_name": "Cliente de démonstration",
    "phone": null,
    "email": null
  },
  "practitioner_external_id": null,
  "service_external_ids": ["service-789"],
  "notes": null
}
```

Identifiers are case-sensitive, nonempty, at most 200 characters, without leading/trailing whitespace or ASCII control characters. The sender must provide a stable client identity; do not derive one from a person's name. Service IDs contain 1–10 distinct entries; ordering has no meaning. Date/time fields require UTC or an explicit offset. Local Casablanca wall-clock strings without an offset are rejected. No supplied roles, appointment status, price or duration are accepted. Clinic catalog mappings and server snapshots will determine those values. This first contract covers booking requests; cancellations, refunds and two-way changes require a subsequent contract.

## Persistence rules for the next increment

The pure planning helper is not a substitute for transactional idempotency. The future database command must look up receipts by provider/event ID and bookings by provider/booking ID under appropriate locks, and persist receipts atomically with appointment snapshots and notification records. Identical delivered events return their previous result; changed content under the same event ID is a conflict. Older events cannot overwrite a newer booking. Equal or newer events for an existing booking require review until update ownership and ordering rules are agreed. Staff changes must not be silently overwritten.

Unmapped services, clients or practitioners must go to a review queue with a reason; do not guess mappings by name, auto-confirm an unavailable time, or create fake catalog entries. Validate shifts, absences and overlapping reservations using the existing appointment lock discipline before reserving a practitioner. Imported source stays WEBSITE; preserve external identity and price/name/duration history. Notifications need a unique recipient/event key and must be committed with the booking. Raw personal data and signing keys must not appear in logs.

## Remaining Phase 5 work

- Transactional receipt/review queue, external mappings and guarded import command, with database permission and race tests.
- Deployment configuration, sender delivery retries and verification against the real HTTPS receiver.
- Persistent external mapping configuration and full reconciliation/dismissal workflow.
- Website-side durable delivery, contract verification with its developer and a real end-to-end booking test.

Current checks cover signature tampering, wrong keys, expired timestamps, body limits, schema validation, stable fingerprints, duplicate planning and stale/update protection. They do not prove database ingestion or provider interoperability. Phase 5 is **in progress**.


## Database review/import increment

Apply migration `202609100009_website_inbox.sql` after 001–008. `receive_website_booking(event_payload)` is executable only by `service_role`; the future receiver must first authenticate and normalize the payload using the signed adapter. It stores a durable REVIEW event, rejects reused event IDs with different payloads and returns the same receipt for replays. The receipt payload contains client personal data and is readable only by active staff through RLS. Direct staff inserts/updates/deletes are denied.

`GET /api/v1/website-bookings?state=REVIEW&page=1` returns 50 rows per page. Both roles can review. `POST /api/v1/website-bookings/{id}/import` takes `version,client_id,practitioner_id,service_ids,expected_total_centimes,expected_duration_minutes`. Staff explicitly select existing clinic records; no persistent automatic external mapping exists yet. Use the existing quote endpoint for the event’s requested start before import. The import command checks the quote again, locks the booking transaction and catalog rows, validates availability and creates a WEBSITE / NEW appointment with authoritative snapshots. It marks the receipt IMPORTED, writes an audit entry and inserts one notification per active staff account in the same transaction. Failed checks roll back all import changes and leave REVIEW intact.

An existing external booking ID or another equal/newer event requires reconciliation rather than overwriting an appointment. Repeating the import command after success returns 409; refresh the receipt to retrieve its appointment ID after an uncertain response. Replaying the original delivery returns the persisted receipt. REVIEW events are durable; there is currently no reconciliation API, background retry worker or queue retention job. DISMISSED is now supported by the review workflow in migration 010.

Database tests cover receipt replay/conflict, denied direct writes, USER import, snapshot creation, notification deduplication, scheduling rollback, existing-booking protection and anonymous/disabled access. PGlite runs the nine migrations with Auth/Storage fixtures; multi-connection PostgreSQL races and live Supabase remain unverified. Flutter now exposes review/import screens through Plus for both roles. See the UI increment below.


## Flutter review increment — 11 September 2026

Both ADMIN and USER can open Réservations en ligne in Plus. The Figma Make context was rechecked and the saved OnlineBookings source re-inspected before implementing its header, blue accents, tabs and bordered cards with the existing theme/icons. Queue tabs reflect REVIEW/IMPORTED rather than claiming appointment confirmation. Refresh reloads stored events; it does not display an invented provider synchronization status. Unmapped service references are visible during review rather than guessed service names or prices.

The shared five-step appointment form now supports website import: explicit client/service/practitioner selection, fixed requested instant and original notes, a real server quote, and the guarded import endpoint. It shows the resulting NEW appointment after success. Failed saves preserve selections and surface errors. Existing manual creation is unchanged. Back out and refresh the queue after an uncertain successful import or a version conflict to recover the saved appointment. List reads use pagination, retry, empty states and stale-response protection. No incoming website events will exist until the signed receiver and website sender are connected.

The new visual baseline is a Flutter test render, not an Android device screenshot or a pixel comparison against Figma. No Android build, live website/Supabase verification or deployment is included.


## Opt-in receiver — 11 September 2026

`POST /api/v1/integrations/website-bookings` is now implemented. Leave `WEBSITE_WEBHOOK_ENABLED=false` until both systems are ready. Set `WEBSITE_WEBHOOK_SECRET_HEX` to a dedicated 32-byte random key encoded as 64 hex characters, exchanged securely with the website developer. The endpoint also needs the existing Supabase service-role configuration and `RATE_LIMIT_SECRET`. Never store the webhook secret in Flutter, public environment variables, source control or logs. No key has been generated or live configuration enabled by this delivery.

The receiver validates timestamp/signature, bounded raw bytes and normalized schema before using privileged database access. Valid deliveries share a PostgreSQL-backed allowance of 60 requests per minute, including replays; arbitrary IP headers cannot evade it. The limiter fails closed. This is an authenticated-delivery quota, not a replacement for hosting-layer denial-of-service protection. Apply migration 009 before enabling reception; earlier migrations supply the durable limiter.

Response contract:

| HTTP | Meaning | Sender action |
| --- | --- | --- |
| 202 | New event durably stored in REVIEW | Mark delivered; staff import is separate |
| 200 | Identical event already stored | Mark delivered; use returned receipt |
| 400 / 413 | Invalid event/content or oversized body | Correct the payload; do not retry unchanged |
| 401 | Invalid signature or expired delivery timestamp | Check secret and clock; sign a fresh attempt |
| 409 | Event ID reused with different content | Reconcile event identity; do not overwrite |
| 429 | Provider delivery quota reached | Honor `Retry-After: 60`, then retry with jitter |
| 503 | Disabled/misconfigured receiver or unavailable persistence | Retain outgoing event; retry with bounded backoff |

Successful responses contain `id,state,appointment_id,replayed`. Acknowledgement is sent only after the database returns a valid durable receipt. If the connection fails after commit, a retry returns the existing receipt. Request bodies, personal data and signatures are not logged by the route. No automatic appointment confirmation or outbound website update is performed.

Route tests exercise real HMAC verification with a test-only key and mocked database responses, including disabled configuration, malformed payloads, invalid signatures, throttling, storage failure, duplicate receipts and event conflicts. Separate PostgreSQL tests verify actual receipt/import transactions. Full HTTP→Supabase→Flutter verification and website interoperability remain pending.


## Dismissal workflow — migration 010

Apply `202609110010_website_dismissal.sql` after migration 009 before using the updated queue API. Both active roles may POST `/api/v1/website-bookings/{id}/dismiss` with `{version,reason}`. The reason must contain 3–500 characters after trimming. Only REVIEW events may be dismissed; stale versions and imported/dismissed events return 409. The database stores the reason, reviewer and timestamp, increments the version and writes an audit event in one transaction. Unknown records return 404. Direct table writes remain denied.

Flutter provides Écarter la demande in the review dialog, preserves the reason on failed saves, and includes an Écartées tab to read the reason later. Dismissal does not cancel an imported appointment, contact the website, or erase the original event. Replayed delivery returns the dismissed receipt without reopening it. There is no automatic reactivation or reconciliation of subsequent equal/newer provider events in this increment.


## Combined delivery verification

The signed-delivery flow suite now invokes the real Next receiver and signature adapter, bridges only the Supabase RPC transport to PGlite, and executes the real rate-limit, receipt and import SQL. It verifies a signed event entering REVIEW, a USER importing it with snapshots, one notification per active account, and a replay returning the imported appointment. It also verifies tampered signatures do not reach the database, reused IDs cannot overwrite payloads, and occupied slots retain a durable review request without creating another appointment.

This closes the gap between the separate route and database tests. It is not a live network/Supabase Auth/PostgREST test, a multi-connection race test, or verification of an actual website sender. The website developer still needs to implement durable outgoing delivery against the documented contract. No provider credentials, production event, remote deployment or migration were used.
