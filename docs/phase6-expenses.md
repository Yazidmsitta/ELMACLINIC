# Phase 6 — expenses

## Monthly summary API

Apply migration `202609110014_expense_summary.sql` after 013. GET `/api/v1/expenses/summary` is ADMIN-only at both HTTP and database layers. It returns `currency: MAD`, `clinic_date`, `month_centimes` and `month_transactions`. The accounting date `spent_on` determines month membership using the current Casablanca calendar month. Cancelled expenses are excluded, and totals cover every matching record independently of list pagination. An empty month returns zero. Flutter now requests this endpoint on initial load, refresh and after forms close. Summary failures preserve list access and offer retry without presenting zero totals.

Regression coverage includes 51 active records, both month boundaries, cancellation exclusion and USER denial.

Apply migration `202609110013_expense_commands.sql` after 001–012. The Flutter ADMIN Plus menu now opens the expense list, create/edit sheet and reason-required void flow. Only active ADMIN profiles may read or modify expenses, enforced in the HTTP routes and database functions/RLS.

- GET `/api/v1/expenses?page=1&state=active` returns 50 rows per page. Use `state=voided` for cancelled entries.
- POST `/api/v1/expenses` accepts `description`, `category`, positive integer `amount_centimes` (MAD), `spent_on` (YYYY-MM-DD) and UUID `request_id`. Reuse the same key and payload after an uncertain save. The database assigns the recorder.
- PATCH `/api/v1/expenses/{id}` accepts all four editable fields plus `version`. It preserves the original recorder, increments the version and audits the previous values.
- DELETE `/api/v1/expenses/{id}` accepts `version` and a 3–500 character `reason`. It marks the record voided, retaining its amount, history, reason and audit entry. It does not physically delete the row or reverse a bank transaction.

Creation retries return the original ID. Reused keys with different payloads, stale edits and changes to voided expenses return 409. Missing update/delete records return 404. USER receives 403. Direct inserts, edits and deletes remain denied even to authenticated ADMIN sessions; changes go through guarded commands. Categories are free-text labels until a clinic taxonomy is specified. No financial report should include voided entries as active expenses.

Tests exercise USER isolation, idempotency, stale-version rejection, audit history, required void reasons and HTTP validation. PostgreSQL tests use the local PGlite fixture engine. Live Supabase, multi-connection races and Android verification remain pending; this API does not move money.

## Flutter implementation

Typed domain and Dio repository connect to the expense endpoints. The list supports active/voided filters, refresh, pagination and errors. Creation retries keep the draft and request ID; edits and cancellations submit the reviewed version. Session identity changes dismiss protected routes.

The connected Figma Make Expenses.tsx was inspected before implementation: category chips, olive badges, white rounded cards and the sheet reuse centralized ElmaClinic tokens. Categories are suggested labels, not a database enum. The monthly summary cards use the independent server endpoint. Payment-method text remains deferred because expenses do not record a payment method; page sums are not represented as monthly totals. Date and cancellation controls extend the established components.

Verification: 69 Flutter tests pass, including expense retry, reason/version, filter and visual coverage. The expense rendering was visually inspected at 390 × 844. Live Supabase and Android-device validation remain pending.

Expense API adapter regression tests cover summary currency/date/amount validation, malformed list records, history pagination, exact mutation payloads and HTTP failures. Invalid accounting dates, non-positive amounts and invalid versions are rejected before presentation. Flutter analysis is clean.
