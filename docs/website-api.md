# Website API

The website can be built later. Its backend can read GET `/api/v1/integrations/catalog?page=1` after migration 021 and explicit configuration. Set WEBSITE_CATALOG_ENABLED=true and configure WEBSITE_CATALOG_SECRET_HEX with a separate 32-byte random hex key. Keep it exclusively on the website server and API server; never put it in browser JavaScript or Flutter. A Supabase project and HTTPS API deployment are still required.

Send `x-elma-timestamp` (Unix seconds) and `x-elma-signature` (`sha256=` plus hex HMAC-SHA256). Sign exactly `timestamp.GET.pathname?query`, using the key decoded from hex; omit `?query` when absent. Requests expire after five minutes. The signature binds query order and encoding. Do not reuse the booking webhook key. Valid requests share a durable 60/minute limit; 429 includes Retry-After. Authentication failures return 401, disabled configuration 503 and invalid page 422.

Response fields: categories (id, name, parent_id, sort_order), services (id, category_id, name, description, duration_minutes, price_centimes), practitioners (id, full_name, specialty), currency=MAD, page, per_page=50, total_services, has_more. Pagination applies to services; categories and practitioner display lists accompany each page. Inactive/deleted categories and descendants are excluded, as are services under them. Services without a category remain listed. Only active, non-deleted practitioners appear. No client data, practitioner contacts or internal account information is exposed.

For booking submissions, the existing signed POST `/api/v1/integrations/website-bookings` contract remains separate. Submissions enter staff review and become WEBSITE appointments only through the validated import flow. Catalog availability is not a reservation: the website must not promise a confirmed slot from a catalog response. Public bookable-slot discovery remains pending. Staff CRUD continues to use authenticated ADMIN APIs.

Production origin: https://elmaclinic-api.vercel.app

Verified after deployment: signed catalog GET returns 200; unsigned catalog and unauthenticated staff return 401. Both demo roles log in; staff listing returns 200 for ADMIN and 403 for USER. Booking receiver remains disabled until the website sender is configured. Signing secrets are stored in server/.env.local and Vercel production environment variables; transfer the catalog key only to the website server environment.
