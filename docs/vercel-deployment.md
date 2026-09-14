# Vercel API deployment

Deploy the `server` directory as a Next.js project using Node.js 24. The production build passes locally. `.vercelignore` excludes local credentials and build artifacts from uploads.

Configure these server-only production environment variables in Vercel: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SERVICE_ROLE_KEY and RATE_LIMIT_SECRET. Set TRUST_VERCEL_PROXY=true. Never prefix privileged variables with NEXT_PUBLIC_. Keep ALLOW_DEMO_PROVISIONING=false and do not upload DEMO_PASSWORD.

The Supabase URL is https://ofaabqwxkabyajbhlmwj.supabase.co. Rotate the service-role credential that was accidentally stored in `.env.example` before production, and update `.env.local` and Vercel with its replacement. The template has been sanitized.

For the future website, configure separate random 32-byte hex WEBSITE_CATALOG_SECRET_HEX and WEBSITE_WEBHOOK_SECRET_HEX values on the API and website servers. Enable the associated WEBSITE_CATALOG_ENABLED and WEBSITE_WEBHOOK_ENABLED flags only when their server-side callers are configured. See website-api.md for the signed request contract. Do not place these secrets in website browser code.

After deployment, verify unauthenticated staff endpoints return 401, USER financial and management actions return 403, both staff roles can log in, and signed catalog requests succeed when enabled. Test website submissions using a dedicated test booking; submissions enter staff review, not automatic confirmation. Set Flutter API_BASE_URL to the deployed HTTPS origin followed by /api/v1/.

Production API: https://elmaclinic-api.vercel.app/api/v1/. Deployment and live login/catalog/role checks passed. Website booking intake is disabled until sender setup.
