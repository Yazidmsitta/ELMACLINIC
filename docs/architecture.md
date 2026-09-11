# Application architecture

Phase 2 addition: `GET /api/v1/dashboard` calls an invoker-rights PostgreSQL function. It computes clinic-day boundaries in Africa/Casablanca, aggregates persisted records, and excludes financial response keys for USER. Flutter consumes typed dashboard entities through a repository and renders loading/error/empty/data states. See `design-phase2.md` for the UI mapping and asset provenance.

Flutter separates domain contracts, API/session adapters and presentation. It connects only to Next.js. Access and refresh tokens are stored together in Android secure storage. Concurrent expired requests share refresh; requests retry once. Release requires HTTPS.

Next.js validates tokens through Supabase Auth and reads active profiles using the same JWT. Roles never come from email or editable Auth metadata. Normal queries use RLS. Rate limiting, demo provisioning, Auth revocation and sanitized service-image uploads use privileged server credentials. Catalog and availability database writes retain the caller’s JWT/RLS checks.

PostgreSQL policies call a private fixed-search-path security-definer helper to check the active profile and session ownership in auth.sessions. This avoids recursive profile RLS and rejects revoked sessions before JWT expiry. Every core table has RLS. Client updates use column grants; ADMIN archival preserves history and logs the action. Other mutations remain denied until dedicated business commands exist.

Appointment sources are MANUAL/WEBSITE (Manuel/Site web). Seven statuses are constrained. External provider/id pairs are unique for future synchronization. Appointment services snapshot price/name/duration. Services and practitioners support active status and archival. Amounts use integer centimes and payment currency is MAD.

Website integration remains a future adapter; no elmaclinic.ma endpoint is invented. Before ingestion, implement authenticated webhooks or an agreed polling contract, idempotent events, transactional scheduling checks, retries, reconciliation and notification deduplication. Manual appointment creation and operational edits use guarded PostgreSQL commands; external ingestion is not implemented.

Single-clinic scope. Phase 3 adds catalog column grants and ADMIN policies, audited archival, a serialized two-level category tree, transactional availability replacement, and private image storage. Uploaded images are decoded/re-encoded by Next before a guarded database function links them to a service. No persistent server memory is required on Vercel; the auth limiter uses PostgreSQL. Reports and financial commands remain later phases. See `phase3-catalog.md`.

Phase 4 adds typed appointment repositories, clinic-day reads, server quotes, transactional creation with idempotency keys, version-checked rescheduling/status changes and ADMIN archival. Database commands serialize booking changes, lock practitioner rows and validate shifts, absences and overlapping reservations. Availability replacement rejects changes that strand existing bookings. Price/name/duration snapshots and MANUAL/WEBSITE sources survive edits. See `phase4-appointments.md`.
