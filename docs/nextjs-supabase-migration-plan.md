# ELMACLINIC — architecture audit and migration proposal

Date: 9 September 2026. Historical proposal: subsequently approved by the user. Phases 1–4 are implemented locally; see README and verification notes for the current state. The proposal text below preserves the original audit.

The attached instructions supersede the original backend choice. The target is Flutter Android → HTTPS → Next.js/TypeScript → Supabase PostgreSQL/Auth/Storage. There will be no Laravel or MySQL dependency in the target application.

## 1. What was inspected

The existing project is in `outputs/elmaclinic/`. Inspection covered the Laravel API routes/auth controller/migrations, Flutter authentication repository, user model, token persistence, shell/theme, dependency manifest, CI and previous verification report.

The visual reference is [Elmaclinic app — Figma Make](https://www.figma.com/make/kIkeh84KnP84ySK7fjn3VE/Elmaclinic-app). The inspected file showed Version 19. The signed-in browser made its preview and source editor accessible even though the Figma connector's design-reading tools were not exposed. This audit uses the actual Make source and rendered preview, not an inferred redesign or a claim of connector extraction.

Read reference files: `index.css`, `icons.tsx`, `App.tsx`, `Login.tsx`, `Dashboard.tsx`, `Appointments.tsx`, `AppointmentDetail.tsx`, `NewAppointment.tsx`, `Patients.tsx`, `Payments.tsx`, `More.tsx`, `Services.tsx`, `Employees.tsx`, and `OnlineBookings.tsx`. The file tree also contains expenses, inventory, reports, settings, notifications within the dashboard, user administration, activity log and online-booking settings. Those additional screens need a detailed visual pass before their implementation.

## 2. Existing architecture and reusable work

| Area | Found | Treatment after approval |
|---|---|---|
| Backend | Laravel 12, PHP, Sanctum bearer tokens, ADMIN Gate and active-user middleware | Replace with Next.js Route Handlers, Supabase Auth and PostgreSQL authorization |
| Database | 15 requested domain tables; integer IDs; MySQL configuration; SQLite tests | Translate the domain model to UUID-based PostgreSQL migrations and RLS |
| Implemented API | Login/me/logout; basic client create/read/update/delete; catalog/appointment reads; own notifications | Preserve behavior and versioned URL conventions where practical |
| Reserved API | Many mutations and reports return 501 after permission checks | Implement incrementally; never turn these into fake successful writes |
| Flutter | Android scaffold; domain/data/presentation separation; Dio; secure storage; French localization; role-aware navigation | Retain structure and contracts; replace the auth adapter and visual implementation |
| Flutter UI | Green Material-style theme; dashboard/module placeholders | Replace with the inspected olive ELMA design system and approved layouts |
| Website integration | Interface/DTO and external identity columns; no connected provider | Preserve the integration boundary and implement an authenticated adapter once its contract is known |
| Tests | Previous report: 15 backend tests / 87 assertions; 7 Flutter tests | Port backend assertions to API/RLS tests, keep and extend Flutter tests |
| Infrastructure | MySQL Compose service and Laravel CI; no verified Android build or live MySQL setup | Replace active backend/CI configuration; add Supabase/PostgreSQL checks and Vercel-ready Next build |

Those test results are historical results from 8 September, not newly executed migration checks. No Next.js/Supabase implementation currently exists in the inspected project. The Figma Make React application is a separate prototype, not the production API.

Preserve the current source archive before migrating. Keep the legacy backend out of the future active workspace/deployment once the replacement passes acceptance tests; do not delete useful history blindly. Verify whether any non-demo database exists before planning data transfer. If there is real data, use a dry-run import with integer-to-UUID mapping and reconciliation; do not assume production data is disposable.

## 3. Figma design system to reuse

Exact values below come from the inspected CSS and screen code.

| Token | Reference value |
|---|---|
| Brand / light / dark | `#6C6B50` / `#E8E8DC` / `#4A4A37` |
| Gold | `#9E9C78` |
| Page / secondary surface / border | `#FAF9F6` / `#F2F2EC` / `#E4E4D8` |
| Primary / secondary / tertiary text | `#1C1C14` / `#5C5C44` / `#9E9E84` |
| Body typeface | Plus Jakarta Sans; generally 11–15 px for supporting text and controls |
| Display typeface | DM Serif Display; 20–24 px screen titles |
| Primary button | 135° gradient `#7E7C5E → #6C6B50`; usually 52 px high |
| Button shadow | Offset `(0,4)`, blur `16`, olive at 32% opacity; dashboard CTA blur `20` at 35% |
| Screen padding / layout gaps | 20 px horizontal; 24 px login form; common gaps 8, 10, 12, 16, 20 px |
| Corners | 12 px fields/small controls; 16 px cards; 24 px sheets; 32 px login panel top corners |
| Fields | Cream fill, warm 1 px border; 44–48 px field height; uppercase labels |
| Navigation | White, warm top border; 20 px outlined glyphs; olive selected, muted inactive; reference height 76 px including its mock safe area |
| Icons | Exact outlined SVG geometry in `icons.tsx`, generally 1.8 px stroke; selective active variants |

Build `ElmaColors`, `ElmaTypography`, `ElmaSpacing`, `ElmaRadii`, `ElmaShadows` and `ElmaTheme`, with semantic status/source tokens. Bundle the actual logo and licensed fonts for offline rendering. Reuse the exact exported/reference icon geometry instead of approximate Material replacements. Inventory image licenses and preserve approved assets; do not generate substitute branding.

Reusable widgets: `ElmaScreenHeader`, `ElmaBottomNavigation`, `ElmaPrimaryButton`, `ElmaIconButton`, `ElmaTextField`, `ElmaCard`, `ElmaAvatar`, `ElmaSectionLabel`, `ElmaFilterChip`, `ElmaBottomSheet`, `AppointmentCard`, `AppointmentStatusBadge`, `AppointmentSourceBadge`, `OnlineBookingCard`, `MetricCard`, `ClientCard`, `ServiceCard`, `PractitionerCard`, `PaymentCard`, and shared loading/empty/error panels.

Preserve the login gradient and white bottom form panel, dashboard card arrangement, date strip, horizontal category filters, photo-topped service cards, practitioner cards, grouped More menus, and modal sheet composition. Use actual Android system insets rather than drawing the Figma iPhone frame, Dynamic Island, fake status bar, or home indicator. Keep the reference's visual proportions while allowing keyboard scrolling, text scaling and Android back navigation.

Status presentation: NEW uses blue/new styling; PENDING amber; CONFIRMED green; IN_PROGRESS purple; COMPLETED neutral; CANCELLED red; NO_SHOW gray. Sources are exactly `MANUAL → Manuel` and `WEBSITE → Site web`.

## 4. Requirements that override the prototype

1. **Authentication:** Make's login checks for nonempty fields and chooses a local user by email; unknown users fall back to a guest. That behavior will not be copied. Supabase must verify the password, then the application must load the protected profile. No role selector or public staff signup.
2. **Roles:** Make's dashboard renders revenue and its chart without a role guard, and More exposes Reports to USER. Remove unauthorized financial data from both API responses and USER screens. USER still gets daily appointments, website bookings, basic clients, read-only services/practitioners and payment recording.
3. **Navigation:** Use **Clients**, as requested, where Make says Patients. USER needs an accessible Prestations entry even though the inspected More source places it in its admin section. Preserve card/menu styling and group structure without duplicating admin entries unnecessarily.
4. **Mutations:** Some prototype actions only update React memory; some edit sheets announce success without persisting all form fields. Implement real validated API writes, errors, duplicate protection and audit events. No simulated saved/reset-email/synced states.
5. **Data:** Make contains fixture dates, people, revenue and activity counts. Earlier prototype messages describe assumed service prices. These are visual examples, not approved clinic records or authoritative prices. Keep any visual-test fixtures isolated from live data.
6. **Sources:** Never introduce `APPLICATION`. Manual creation is server-assigned MANUAL. Only the verified integration ingestion path assigns WEBSITE. Existing website appointments retain their source when staff edit their operational status.
7. **Recovery/remember-me:** Wire recovery to a real Supabase flow with configured email delivery; until available, do not claim an email was sent. Define whether “Se souvenir” persists the session across app restarts; never persist the password.

## 5. Proposed API and authentication

Use Next.js App Router Route Handlers under `/api/v1`, running in the Node.js server runtime. Controllers stay small; validation, authorization, use cases and Supabase access live in separate modules. Next.js documents the standard Route Handler model [here](https://nextjs.org/docs/app/api-reference/file-conventions/route).

Proposed authentication endpoints: `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`, `POST /auth/logout`, and a real password-recovery flow when email delivery is configured. Login returns the Supabase access token, refresh token, expiry and typed profile; IDs become UUID strings. Flutter keeps the access/refresh session securely, serializes refresh attempts, retries a failed authenticated request at most once, and clears the session after definitive authentication failure. Transient network failures remain retryable.

Verify identity on the server with the supported Supabase Auth API, then read `profiles.role` and `profiles.is_active` from the database. Never trust a body parameter, user-editable metadata or a locally decoded unsigned JWT for authorization. Supabase's `getUser(jwt)` verifies through the Auth service; session handling must account for access/refresh token behavior. [Identity verification](https://supabase.com/docs/reference/javascript/auth-getuser), [sessions](https://supabase.com/docs/guides/auth/sessions).

Use a **request-scoped Supabase client with the user's bearer token for normal database operations**, preserving RLS. Do not use a shared client carrying another user's session. Keep the secret/service-role client in a server-only module, limited to provisioned administrative tasks and verified integration ingestion. Supabase's privileged role bypasses RLS; it must never reach Flutter or a browser bundle. [RLS and grants](https://supabase.com/docs/guides/database/postgres/row-level-security).

Database profile checks make role changes/deactivation effective on subsequent protected operations. For logout, explicitly test Supabase's access-token revocation behavior; short-lived JWTs are not automatically equivalent to Sanctum's deleted tokens. The proposed immediate-revocation safeguard is a tightly scoped database helper checking the verified session ID against active Auth sessions, used consistently by API/RLS authorization. Do not claim instant revocation until the integration test passes.

Use shared PostgreSQL-backed rate limiting for application endpoints rather than process-local counters on Vercel. Use stable JSON error codes, French presentation messages, UUID validation and explicit response DTOs. Return 401 for invalid identity, 403 for forbidden operations, 409 for booking/payment conflicts, 422 for validation and 429 for throttling. RLS may filter reads to zero rows rather than produce 403; Next.js must explicitly authorize forbidden actions before running them and map database denials consistently.

## 6. Proposed normalized PostgreSQL schema

Assumption: one clinic with many staff, not a multi-tenant SaaS. Every application table has a UUID primary key plus `created_at`/`updated_at` as `timestamptz`. Use generated UUIDs, UTC storage, and Africa/Casablanca when interpreting clinic schedules. Ledger/audit rows retain timestamps but are not editable. Monetary amounts use integer centimes (bounded to safe API integer ranges); currency is constrained to MAD.

| Table | Main proposed fields and relationships |
|---|---|
| `auth.users` | Supabase-managed authentication identity/passwords; no app-owned password column |
| `profiles` | `id` PK/FK to Auth user; `full_name`, `role ADMIN/USER`, `is_active`, optional `job_title`, `avatar_path`. Disable accounts to preserve historical references |
| `clients` | `full_name`, `phone`, `email`, optional `birth_date`, `created_by → profiles`, `deleted_at`; keep financial/clinical/private notes out of the basic staff record |
| `practitioners` | `full_name`, optional linked `profile_id`, `specialty`, work contact fields, `avatar_path`, `is_active`, `deleted_at`; staff login and practitioner identity remain distinct |
| `practitioner_schedules` | `practitioner_id`, ISO `weekday 1–7`, local `starts_at/ends_at` times, `valid_from/valid_until`; split overnight hours into separate records |
| `service_categories` | `name`, optional `parent_id`, `sort_order`, `is_active`, `deleted_at`; parent categories support Épilation → Visage/Corps/Homme/Packs |
| `services` | `category_id`, `name`, `description`, `duration_minutes`, `price_centimes`, `image_path`, `is_active`, `deleted_at` |
| `appointments` | `client_id`, nullable `practitioner_id` for unassigned website requests, `starts_at`, `ends_at`, exact source/status enums, `created_by`, `notes`, `external_provider`, `external_id`, `external_updated_at`, `synced_at`, `version`, `deleted_at` |
| `appointment_services` | `appointment_id`, `service_id`, `service_name_snapshot`, `duration_minutes_snapshot`, `unit_price_centimes`, `quantity`; deliberate historical snapshots, not live price lookups |
| `payments` | `appointment_id`, `recorded_by`, positive `amount_centimes`, `currency`, `method CASH/CARD/TRANSFER`, `paid_at`, unique `idempotency_key`; correction/refund records reference an original payment rather than overwriting it |
| `expenses` | `description`, `category`, `amount_centimes`, `spent_on`, `recorded_by`, optional private receipt path, `voided_at`; audited corrections |
| `products` | `sku` unique, `name`, `unit`, `cost_centimes`, `reorder_level`, `image_path`, `is_active`, `deleted_at` |
| `inventory_transactions` | `product_id`, `recorded_by`, signed nonzero `quantity_delta`, `reason`, optional related appointment and reversal reference; stock derives from the ledger |
| `notifications` | `recipient_id`, `type`, optional `appointment_id`, minimal `payload`, `read_at`; ownership enforced; unique event/recipient identity avoids duplicate alerts |
| `activity_logs` | `actor_id`, `action`, `entity_type`, `entity_id`, `request_id`, allowlisted redacted metadata; append-only, admin-readable |
| `settings` | unique `key`, `group`, validated `value jsonb`, `updated_by`; no API secrets, tokens or passwords |

Supporting tables added when their phase begins: `practitioner_time_off` for dated exceptions; `integration_mappings` for external service/practitioner IDs; private `integration_events` for replay protection and processing status; private `integration_sync_state` for cursors; `integration_outbox` for reliable two-way changes; `payment_adjustments` for refunds/corrections; private rate-limit buckets with retention.

Constraints/indexes:

- `ends_at > starts_at`, positive durations/quantities, nonnegative prices, positive payments, valid schedule date ranges, and only approved enum values. Confirmed/in-progress/completed appointments must have a practitioner.
- Foreign keys restrict deletion of referenced historical services/practitioners/clients. UI deletion means soft deletion or deactivation where history exists.
- Composite unique website identity `(external_provider, external_id)` when present. Website identity/source is immutable to operational staff.
- PostgreSQL range/exclusion protection for overlapping active bookings of a practitioner (`PENDING`, `CONFIRMED`, `IN_PROGRESS`), with unassigned WEBSITE requests excluded until assigned. Validate opening hours and time-off inside the booking transaction too.
- Index FK columns and operational queries: `(starts_at,status)`, `(practitioner_id,starts_at)`, `(source,status,starts_at)`, client phone/name search, `(recipient_id,read_at,created_at)`, `(product_id,created_at)` and payment appointment/time.
- Unique idempotency keys with payload consistency checks. Lock the appointment while recording payments to prevent concurrent overpayment; lock the product when enforcing nonnegative stock.
- Historical price/duration/name snapshots and appointment end time are derived server-side in one transaction. USER never submits trusted price totals.

## 7. RLS and write-permission proposal

Enable RLS and explicitly set grants for every exposed table. Default deny for unauthenticated access. Database helpers use the current profile, a fixed search path, qualified object names and minimal privileges; avoid recursive policies on `profiles`. No broad SECURITY DEFINER function or service-role route may become a permission bypass.

| Resource | ADMIN | USER |
|---|---|---|
| Profiles/users | Provision/change roles/deactivate through protected server administration | Read own profile; no role/active-state writes |
| Basic clients | CRUD, historical deletion protected | Read/create/update approved contact fields |
| Services/categories/practitioners | CRUD and active-state management | Read authorized catalog/availability; no writes |
| Schedules/time-off | Manage | Read availability |
| Appointments/items | Manage through transactional commands | Daily operational create/update/status actions through the same commands; no price/source overrides |
| Website bookings | Manage | View, confirm/cancel and assign permitted operational fields; no integration configuration |
| Payments | Full authorized ledger/adjustment access | Record via guarded command; receive a receipt and appointment balance, not an unrestricted global financial query |
| Expenses/products/inventory/reports | Authorized administrative access | Denied |
| Notifications | Read own; system creates | Read own and mark own rows read; cannot alter recipients or payloads |
| Activity logs | Read; system appends | Denied |
| Settings/integration internals | Admin configuration; secrets stay private | Denied |

RLS controls rows, not which columns may be changed. Use explicit column grants and narrowly scoped database commands for role changes, schedules, price snapshots, payments, notification read state and integration fields. Direct Supabase calls must not bypass these restrictions. Protect the last active admin against concurrent deactivation/demotion. Derived financial views must be admin-only and must not bypass underlying restrictions.

Storage proposal: private buckets for receipts and staff/client media, with matching object policies, size/MIME limits and short-lived authorized URLs. A separate public bucket may contain only deliberately public service marketing images. Never mix private clinic documents into public image storage.

## 8. Proposed folder structure

Keep `mobile/` where it is to preserve the working Android scaffold. Add `server/` and `supabase/`; avoid an unnecessary whole-repository move.

```text
elmaclinic/
  mobile/
    lib/
      app/                    composition, routing and session bootstrap
      domain/
        entities/             UUID-based business entities and enums
        repositories/         contracts, independent of Dio/Supabase
        use_cases/            business operations
      data/
        api/                  Next API client and refresh coordinator
        models/               JSON DTOs and mappers
        repositories/         implementations
        services/             secure session persistence
      presentation/
        theme/                extracted ELMA tokens
        widgets/              reusable reference-matched components
        features/             auth, dashboard, appointments, clients, etc.
    assets/                   original logos, fonts and icons
    test/                     unit, widget and visual regression tests
    integration_test/         Android auth and operational flows
  server/
    src/app/api/v1/           Next Route Handlers
    src/server/auth/          identity, active profile, permission checks
    src/server/services/      domain workflows
    src/server/repositories/  Supabase adapters
    src/server/supabase/      request-scoped and isolated privileged clients
    src/server/integrations/  website adapter, signatures and event processing
    src/server/validation/    request schemas
    src/contracts/            DTOs, errors and generated database types
    tests/                    API and business integration tests
    .env.example              variable names only
  supabase/
    config.toml
    migrations/               tables, grants, RLS, functions and constraints
    tests/                    pgTAP allow/deny and concurrency checks
    seed.sql                  non-sensitive local fixtures only
  docs/
    api/                      versioned API contract
    design/                   Figma mapping and visual acceptance checklist
  .github/workflows/         TypeScript, PostgreSQL/RLS, Flutter and Android checks
```

Use an OpenAPI contract for the Dart/TypeScript boundary, not shared TypeScript code inside Flutter. Server environment: Supabase URL, publishable key, isolated secret/service-role key, website signing secret and deployment settings. Flutter configuration contains only the Next API base URL; it contains no privileged Supabase credential. Provision local/demo Auth accounts through a guarded script or Auth admin API rather than inserting password rows manually.

## 9. Website booking flow

Prefer a signed website webhook to frequent polling: website → Next ingestion route → validated, deduplicated transaction → appointments/items + notification → Flutter refresh via Next API. Foreground refresh/pull-to-refresh provides the initial notification update path; no new Realtime dependency is needed initially.

Validate the raw-body signature, timestamp and event ID; reject replays. Map external IDs explicitly. Assign WEBSITE and accepted status server-side. Do not let external payloads choose staff roles, trusted prices or clinic settings. Persist incoming event state before acknowledging successful acceptance, and make processing retry-safe. Use authenticated bounded processing for queued retries; do not rely on a serverless function continuing after its response.

If the provider supports only polling, use cursor-based incremental sync and agree a refresh latency compatible with the hosting plan. Vercel documents Hobby cron as once per day with imprecise scheduling, so it is not a near-real-time synchronization mechanism. [Cron limits](https://vercel.com/docs/cron-jobs/usage-and-pricing).

Two-way sync adds an outbox, provider versions, retries and a documented conflict policy. API contract, provider authentication, ID mapping and cancellation/update rules are still unknown. No claim of a working elmaclinic.ma API integration is justified yet.

## 10. Cost and deployment constraints

Supabase Free currently includes 500 MB database storage, 1 GB file storage and 50,000 monthly active users, with project pausing after inactivity. That is a reasonable initial development target, with compressed images, bounded logs and paginated queries. Backups need an explicit development procedure; automatic backups are not included in Free. [Supabase pricing](https://supabase.com/pricing).

Vercel Hobby is limited to personal, non-commercial use. A clinic business project is not automatically eligible because the environment is labeled development/testing. Keep the Next application Vercel-deployable, but start locally until the eligible hosting plan is resolved. Do not activate a paid subscription or assume a €0 clinic deployment. [Vercel Hobby](https://vercel.com/docs/plans/hobby).

Avoid adding paid queues, Redis or continuous polling by default. Use PostgreSQL for short transactional commands and bounded retry state. No cloud resources, public access changes or paid plans are part of this audit.

## 11. Phased implementation and acceptance

| Phase | Deliverable | Acceptance gate |
|---|---|---|
| 0 — Approval | This audit, schema and design mapping | Confirm the migration direction and first implementation slice |
| 1 — New foundation | Next TypeScript project, Supabase migrations/RLS, protected login/refresh/me/logout, UUID contracts, local demo provisioning, revised CI | Real Auth login; both roles; wrong/expired credentials denied; direct database/API escalation denied; token refresh/logout tests |
| 2 — ELMA shell | Exact tokens/assets, login, main navigation, role-aware More, dashboard composition with real/empty/error states | Side-by-side review at 390 px reference width and Android sizes; no fake business metrics; USER financial sections absent |
| 3 — Catalog and clients | Real clients CRUD, ADMIN prestations/praticiennes CRUD, categories, schedule/time-off and Storage policies | USER writes return 403; direct RLS attempts fail; inactive history preserved; fields and images persist |
| 4 — Appointments | Day strip, filters, appointment cards/details/form, state transitions and service snapshots | MANUAL/WEBSITE only; concurrency/conflict tests; server-calculated prices; date/time correctness |
| 5 — Website bookings | Verified ingestion adapter, idempotency, mappings, notification records and operational review screens | Replayed event creates no duplicate; real provider sample becomes a WEBSITE appointment and appears in app |
| 6 — Payments and administration | Payment recording/adjustments, expenses, inventory, reports, user management, settings, audit screens | Financial access denied to USER; payment/stock transactions correct; admin actions audited; last-admin protection |
| 7 — Release preparation | Hosting decision, environment separation, migrations/backups, Android SDK/device tests and signing | Production secrets absent from APK/source; release build/device smoke tests; deployment and restore checks |

Before each screen is coded, recheck its exact source/preview state and reuse the shared components. Visual tests should cover ADMIN/USER, empty/loading/error, form validation, long French labels and accessible text sizes. Source-specific regression tests must reject APPLICATION at the API/database boundary, not just omit it from a dropdown.

The first proposed implementation slice is **Phase 1 only**, preserving the existing mobile behavior while replacing its authentication adapter. Phase 2 follows on the approved design mapping. Website credentials and a real provider contract are needed only when Phase 5 is reached; a paid hosting decision is not required to begin local implementation.

Awaiting approval before large-scale implementation, as requested in the attached instructions.
