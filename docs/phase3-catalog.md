# Phase 3 — catalog, clients and availability

Implemented locally on 9 September 2026, continuing the approved Next.js/Supabase migration. No live database or deployment was changed.

## Implemented behavior

- Clients: both roles search, paginate, create and edit basic information. ADMIN can archive; appointment references remain intact.
- Prestations: ADMIN creates, edits name/description/category/duration/integer-centime price, changes active status, archives and uploads a photo. USER has a read-only catalog. Successful writes are followed by a server reload; errors keep form data intact.
- Praticiennes: ADMIN persists name, job title, specialty, phone, email and active status. Job title is descriptive, not an authentication role. Archival never deletes historical appointments.
- Categories: ADMIN manages two levels and display order. Parent filters include child-category services. Cycles and third levels are rejected. Archive children before their parent; existing service references are preserved.
- Availability: either role reads weekly shifts and dated absences. ADMIN replaces the configuration atomically. A practitioner row lock serializes competing replacements, and overlapping shifts/absences are rejected. Weekly times use Casablanca wall time; absences are stored as absolute timestamps. Flutter converts through the Africa/Casablanca time-zone database rather than the device’s zone.
- Photos: ADMIN chooses an image, previews it and explicitly saves it to an existing prestation. Next limits the body to 2 MiB, decodes JPEG/PNG/WebP, removes metadata by re-encoding, limits resolution and stores a private JPEG. A guarded command links the object to its service. Only referenced, accessible service images receive read access; signed links expire after five minutes.
- Identity changes or expiry close catalog routes. USER cannot retain an admin screen after the authenticated identity changes.

## Security and persistence

Normal database operations use the authenticated caller’s Supabase client. Catalog writes require ADMIN RLS plus column grants; callers cannot assign profile IDs, roles or archival timestamps. Next checks permissions before parsing mutation bodies and returns HTTP 403 for forbidden actions. Direct USER updates may instead affect zero rows under PostgreSQL RLS; tests assert that data remains unchanged. Hard deletes are not granted.

Catalog changes generate activity records in the same database transaction. Availability has a dedicated guarded replacement command and audit event. Existing client archival retains its audit event. Service names, durations and prices already snapshotted on appointments are not rewritten by catalog edits.

Storage uploads use the isolated server service-role client only after verifying ADMIN and the target service. No authenticated Storage upload policy is created. Database linking still checks the caller’s role and object/service identity. Failed linking attempts remove the uploaded object; successful replacements attempt removal of the previous image. Interrupted uploads or failed cleanup can leave unreferenced private objects, so a production cleanup job remains part of release preparation.

Phase 4 supersedes this phase’s booking limitation: migration 008 now rejects availability edits that invalidate existing reserved appointments. See `phase4-appointments.md`. Simultaneous availability editors use last successful replacement semantics; this is not collaborative merging.

## Figma mapping

Source: the connected Figma Make file `kIkeh84KnP84ySK7fjn3VE`, plus the previously extracted `Patients.tsx`, `Services.tsx`, `Employees.tsx` and shared theme/icon source. The original source was re-inspected before implementation.

The implementation retains olive branding, bundled Plus Jakarta Sans/DM Serif Display, warm borders, original icons, 20 px screen padding, 16 px cards, pill category filters, service photo headers, initials avatars and 24 px modal-sheet corners. Category management, archival confirmation and availability controls reuse these tokens where the prototype lacks a complete persisted workflow. Clients replace the prototype’s Patients label as requested. Prototype financial totals, activity counts and sample prices are not production records.

Four new 390×844 Flutter visual baselines cover ADMIN/USER prestations, ADMIN praticiennes and USER clients. They were rendered and visually inspected. A compact 320 px / 1.5× text / keyboard test covers the client form. Existing seven shell baselines continue to pass. These are Flutter test renders, not Android device screenshots or a pixel-diff against the Figma renderer.

Photo picking follows the official [image_picker Android recovery guidance](https://pub.dev/packages/image_picker): recovered files are previewed for explicit saving, never silently linked after a process restart. Clinic time conversion uses the bundled [timezone database](https://pub.dev/packages/timezone).

## Applying and verifying

Apply migrations 003, 004, 005 and 006 in order after the existing foundation/dashboard migrations. Migration 005 requires Supabase’s Storage schema, which the real/local Supabase stack supplies. The automated PostgreSQL tests provide explicit Auth/Storage fixtures, not a replacement Storage server.

Run `npm run typecheck`, `npm test`, `npm run build`, `flutter analyze`, and `flutter test`. The current local checks pass: 24 server tests and 33 Flutter tests, including 11 visual baselines. No live Supabase Auth/PostgREST/Storage round trip, Android gallery picker/device test, APK build or deployment was possible in this environment.

Before staff use, verify a real upload/sign/read round trip, gallery recovery after Android process destruction, ADMIN/USER operations through the hosted API, migration application and database backup/restore. The original phase archives remain unchanged.
