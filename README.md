# ELMACLINIC — Next.js / Supabase foundation

**Flutter Android → Next.js REST API → Supabase PostgreSQL/Auth.** Phases 1–4 implement the foundation, ELMA shell, catalog/client management and appointment workflows. Login, dashboard composition, bottom navigation and role-aware Plus use the inspected Figma Make design, original branding, bundled fonts and extracted icons. Website synchronization and financial workflows remain later phases.

## Included

- Next.js 16/TypeScript, real Supabase password login, token refresh and current-session logout.
- ADMIN/USER roles from active database profiles; API authorization and RLS.
- Fifteen core tables, UUIDs, relationships, constraints, soft archival, MAD amounts in centimes.
- Search and pagination, basic client creation/update, ADMIN client archival.
- ADMIN prestations/praticiennes/categories CRUD with audited changes and soft archival; USER catalog consultation.
- Appointment day view, filters, five-step booking, rescheduling and status transitions, with server-enforced availability, conflict checks and historical snapshots.
- Two-level categories, weekly practitioner shifts and dated absences, private service photos.
- Flutter encrypted session persistence, refresh/retry handling, UUID identity and role-aware navigation.
- Tests, CI and opt-in development account provisioning. Other business mutations return 501 after authorization checks.
- API-backed dashboard counts, schedule previews, own notifications and ADMIN-only revenue; loading, empty and retry states. Prototype metrics are isolated to visual tests.

## Structure

```text
server/src/app/api/v1/   REST routes
server/src/lib/          server-only auth, database clients, HTTP errors
server/scripts/          development account provisioning
server/tests/            API/auth and PostgreSQL policy tests
supabase/migrations/     core schema and RLS
supabase/config.toml     local development services
mobile/lib/domain/      user/repository contracts
mobile/lib/data/        API and encrypted session adapters
mobile/lib/presentation/ preserved screens, widgets and theme
docs/                   architecture, verification and approved migration plan
```

## Supabase setup

Use Node.js 24, Flutter 3.47.2, an Android SDK, and a development Supabase project or the Supabase CLI with Docker.

For local services, run from the repository root:

```sh
npx supabase start
npx supabase db reset
npx supabase status
```

`db reset` recreates the **local development database**. For a hosted development project, apply migrations in filename order through the SQL editor or Supabase migration workflow: `202609090001_foundation.sql` through `202609110023_settings_versions.sql`. If earlier phases are installed, apply only migrations not already applied; do not reset an existing database. Historical Laravel data migration is not included.

On hosted Supabase, disable **Allow new users to sign up** and enable refresh-token rotation. Local configuration already disables signup. Each Auth user requires a matching active `profiles` row. User metadata cannot assign roles. Migration 005 creates the private `service-images` bucket and its read policy. Uploads pass through the ADMIN-only Next endpoint; Flutter receives signed URLs valid for five minutes. Refresh the list to renew URLs.

## API setup

```sh
cd server
npm ci
cp .env.example .env.local
```

Fill `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (publishable or legacy anon key), `SUPABASE_SERVICE_ROLE_KEY` (server-only legacy service-role JWT), and a random `RATE_LIMIT_SECRET` of at least 32 characters. Obtain credentials from your development project or local CLI. Never put privileged credentials in Flutter or `NEXT_PUBLIC_*` variables.

```sh
npm run dev
```

API URL: `http://localhost:3000/api/v1/`. The PostgreSQL auth limiter fails closed when unavailable. Local deployments use a shared bucket. On Vercel only, set `TRUST_VERCEL_PROXY=true` to use its ingress IP header. Limits are 20 login or 120 refresh attempts per minute per bucket, in addition to Supabase Auth limits.

For development accounts, set `ALLOW_DEMO_PROVISIONING=true` and a unique `DEMO_PASSWORD` of at least 12 characters in `.env.local`, then run:

```sh
npm run provision:demo
```

Creates `admin@elmaclinic.test` and `user@elmaclinic.test` through real Supabase Auth. Re-running repairs profiles without resetting existing passwords. Run only against development; afterward disable provisioning and remove `DEMO_PASSWORD`. No remote accounts have been provisioned by this delivery.

## Android setup

```sh
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1/
```

The emulator uses `10.0.2.2` for your computer. Physical devices need a reachable host. Release requires HTTPS and a trailing slash:

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-API-HOST/api/v1/
```

Configure Android signing before distribution. Old Laravel tokens are discarded; staff log in again. Transient network errors preserve the session. “Se souvenir” stores the session securely across launches; unchecked sessions live only in memory. Passwords are never persisted. Password recovery currently directs staff to their administrator; no email-sent confirmation is simulated.

## API contract

Authenticated calls require `Authorization: Bearer <access_token>`. Responses disable caching.

| Route | Contract |
| --- | --- |
| POST `/auth/login` | `{email,password}` → `{session:{access_token,refresh_token,expires_at},user:{id,name,email,role}}` |
| POST `/auth/refresh` | `{refresh_token}` → same shape with rotated tokens |
| GET `/auth/me` | `{user}` from verified identity and active database profile |
| POST `/auth/logout` | Revokes current session; other devices remain signed in |
| GET `/dashboard` | Clinic-day counts, schedule and own notifications; financial keys exist only for ADMIN. Dates use Africa/Casablanca |
| GET `/clients`, `/services`, `/practitioners`, `/categories`, `/schedules`, `/notifications` | Operational reads; `?page=1`, 50 rows; own notifications |
| GET `/payments`, `/expenses`, `/inventory`, `/users`, `/settings`, `/activity-logs` | ADMIN-only reads |
| POST `/clients` | `full_name` required; optional `phone,email,birth_date` |
| PATCH `/clients/{uuid}` | Basic client fields only |
| DELETE `/clients/{uuid}` | ADMIN archival with activity entry |
| POST `/services`, `/practitioners`, `/categories` | ADMIN validated creation |
| PATCH `/services/{uuid}`, `/practitioners/{uuid}`, `/categories/{uuid}` | ADMIN partial update; `active` supported |
| DELETE `/services/{uuid}`, `/practitioners/{uuid}`, `/categories/{uuid}` | ADMIN soft archival, preserving appointment history |
| GET `/practitioners/{uuid}/availability` | Weekly shifts and absolute time-off ranges; either role |
| PUT `/practitioners/{uuid}/availability` | ADMIN atomic replacement: `{shifts:[{weekday,starts_at,ends_at}],absences:[{starts_at,ends_at}]}` |
| PUT `/services/{uuid}/image` | ADMIN raw JPEG/PNG/WebP body, maximum 2 MiB; sanitized private JPEG |

Both roles can record payments through POST `/payments`; the full payment ledger remains ADMIN-only. Restricted actions return 403. Direct role, financial and appointment table writes remain denied; appointments use guarded transactional commands. Catalog writes use ADMIN RLS policies and explicit column grants; schedule writes use a guarded transaction. Full ADMIN permissions do not mean every feature is implemented.

Catalog list parameters: `page` (50 rows), `search` (name substring), and `category_id` for services (includes direct subcategories). The response is `{data,page,per_page,total,has_more}`. A service uses `name,category_id,description,duration_minutes,price_centimes,active`; a practitioner uses `full_name,specialty,job_title,phone,email,active`; a category uses `name,parent_id,sort_order,active`. Fields cannot assign an account role. See [Phase 3 notes](docs/phase3-catalog.md).

Appointment routes: GET `/appointments?date=YYYY-MM-DD` (clinic day, paginated), POST `/appointments/quote`, POST `/appointments`, GET/PATCH `/appointments/{uuid}`, and ADMIN-only DELETE `/appointments/{uuid}`. Creation requires a request UUID and the confirmed quote; mutations require the current version. Configure practitioner shifts before booking. See [Phase 4 setup and API contract](docs/phase4-appointments.md).

## Checks and deployment

```sh
cd server
npm run typecheck
npm test
npm run build
# In mobile:
flutter analyze
flutter test
```

For Vercel, set project root to `server`, select Next.js, and configure the server variables above. No deployment is included. [Vercel Hobby](https://vercel.com/docs/plans/hobby) is for personal/noncommercial use; verify eligibility for clinic work. [Supabase Free](https://supabase.com/pricing) has limited capacity, no automatic production backup guarantees and may pause inactive projects.

The previous Laravel/MySQL source is preserved separately in `ElmaClinic-phase1.zip`; it is no longer an active dependency. See `docs/verification.md` for actual checks and remaining live-service verification.

Phase 5 is in progress: the signed website contract, durable review queue and transactional staff import API are implemented locally. Apply migration 009 for these endpoints. The website has no API yet; Flutter review/import is available through Plus, while live synchronization remains disconnected. See [Phase 5 contract and setup](docs/phase5-website-contract.md).

The Phase 5 receiver is available at POST `/api/v1/integrations/website-bookings`, disabled by default. See the Phase 5 contract for signing, environment variables and retry responses. Enabling it does not configure the website sender.

Apply migration 010 for the website-request dismissal workflow. Staff can retain unusable requests in Écartées with a required reason; this does not cancel website bookings.

Phase 6 payment foundation: apply migration 011 for guarded partial MAD payments and appointment balances. The Flutter collection form is available from appointment details. See [payment setup and contract](docs/phase6-payments.md).

Apply migration 012 for the ADMIN payment ledger and Casablanca day/month collection totals. USER retains only appointment-based collection access.

Phase 6 expenses: apply migration 013 for ADMIN creation, version-checked updates and audited cancellation. The Flutter expense screen and monthly summary are connected (migration 014). See [expense API setup](docs/phase6-expenses.md).

Apply migrations 015–017 for inventory movements, balances/history and versioned product commands. Flutter ADMIN inventory supports listing, product edits and stock adjustments. Migration 018 adds guarded staff editing and session revocation; the Flutter staff editor is connected. Migrations 019–020 add financial report and clinic-profile settings APIs; their Flutter screens remain pending. See [administration progress](docs/phase7-administration.md).

Migration 021 provides the signed server-to-server catalog for the future website. See [website API setup and authentication](docs/website-api.md). No website or Supabase project is required to run the local unit tests; live API operation requires Supabase and server configuration.
