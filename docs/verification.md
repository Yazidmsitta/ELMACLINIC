# Verification — 11 September 2026

Phase 5 review UI increment: 51 Flutter tests pass, including 16 visual baselines. The website queue render was visually inspected. Widget tests cover filtering, failed reloads, explicit mapping, failed import recovery, preserved requested time and use of the website import command instead of manual creation. Latest backend verification: 66 passing tests, TypeScript checks and Next production build. The opt-in signed receiver is implemented and disabled by default; no live website event has been imported.

Phase 4 history: 36 server tests and 46 Flutter tests pass, including 15 visual baselines. Flutter analysis reports no issues; TypeScript checking and the Next production build pass. All eight migrations execute in the PostgreSQL fixture suite. The four appointment renders were visually inspected. Booking snapshots, availability conflicts, idempotency, optimistic versions, role restrictions, API errors and failed-save recovery are covered. PGlite uses one engine: independent database-connection concurrency and full Supabase integration still require verification. See `phase4-appointments.md`.

Phase 3 history: 24 server tests and 33 Flutter tests pass, including 11 visual baselines. TypeScript checking and the Next production build pass. All six migrations run in the PostgreSQL fixture suite; catalog permissions/history, availability replacement, category-tree guards and private image policy are covered. Upload decoding/metadata removal and HTTP permission/error behavior are tested separately. See `phase3-catalog.md` for scope and limitations.

Phase 2 history: Next production build and TypeScript checking pass; 14 server tests cover the additional dashboard RPC, actual persisted totals, clinic time and financial-key omission. Flutter has 17 passing tests including seven visual baselines and remember-session behavior. The source assets and rendered login, role dashboards, Plus, empty/error states were visually inspected. See `design-phase2.md` for render scope. Android SDK/device and live Supabase checks below remain outstanding.

## Phase 1 verification history

- Next.js 16.3.4 production build: passed without cloud credentials.
- TypeScript strict project checking: passed (`skipLibCheck` excludes dependency declaration errors).
- Server tests: 12 passed across API authorization, Auth identity handling and PostgreSQL policies.
- SQL migration executed on PGlite (real PostgreSQL engine) with a test-only Supabase Auth schema fixture. Checked RLS on every core table, USER financial isolation, catalog/role write rejection, client ownership, archival logging, own notifications, disabled/revoked session access, privileged rate limiting, and appointment constraints.
- API tests use mocked provider responses; they verify 401/403/501 behavior and database-derived roles, not live Supabase Auth availability.
- Flutter tests: 9 passed, including login/navigation, invalid roles, session rejection, outage preservation, concurrent refresh and rotation.
- Flutter analyzer: no issues.
- npm audit: zero reported vulnerabilities at verification time.

## Not executed

- A live Supabase project was not configured. No remote migrations, demo accounts, Auth login/refresh/revocation or Storage setup were performed.
- Docker is unavailable here, so the full local Supabase stack (GoTrue/PostgREST) was not run. PGlite tests do not replace that integration check.
- Android SDK is unavailable here; no APK or emulator visual verification was produced. CI includes a debug APK build but has not been run remotely.
- No Vercel deployment, website integration, production data migration, load test or production signing.

## Before connecting staff devices

Apply the migration to a development Supabase instance, disable public signup, configure server variables and provision development users. Verify real ADMIN and USER login from Flutter, restart/session restoration, token refresh, current-device logout, profile deactivation and 403 responses for USER admin actions. Verify direct Supabase requests cannot bypass RLS. Test a physical Android device over HTTPS before distributing any build.

The Phase 2 Flutter shell now uses the inspected Figma palette, bundled typography, original logos, reference icons and screen composition. This is practical design reproduction, not a claim of pixel-perfect Android device verification.

Dismissal increment: all ten migrations execute in the fixture suite. Required reasons, stale versions, imported-event protection and replay preservation pass database tests; Flutter verifies reason validation and failed-save recovery. Analysis is clean and Next production build passes.

Combined delivery verification: the production HTTP handler and HMAC adapter now execute against the PGlite limiter/receipt/import functions through a test RPC transport. The flow suite verifies successful import/replay, invalid signatures, event conflicts and occupied-slot rollback. All 66 server tests pass; TypeScript checking passes. Production code was unchanged in this verification increment.

Phase 6 payment form: 54 Flutter tests pass, with 17 visual baselines. Tests cover exact MAD parsing, excessive amounts, retained idempotency keys and locked retry data. The new payment render was visually inspected. Latest backend run: 73 tests plus TypeScript/production build passed. No live payment, Supabase or Android-device verification is claimed.

ADMIN ledger increment: 74 server tests and 55 Flutter tests pass; all 12 migrations execute in the PostgreSQL fixtures. TypeScript, Next production build and Flutter analysis pass. The 18th visual baseline covers the ADMIN ledger. Receipt archival history and USER RPC denial are checked.

Ledger API regression checks: 59 Flutter tests pass and analysis is clean. Tests verify server totals are not replaced by page sums, integer centimes are preserved, unsupported currency/methods fail closed, 403 remains an error and recording sends the stable request key without privileged fields. The existing ledger implementation and 18 visual baselines are preserved.
