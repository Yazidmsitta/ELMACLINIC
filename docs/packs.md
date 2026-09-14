# Packs and client credit

Migration 024 introduces a pack catalogue with independent MAD price, repeated sessions and mixed prestations. ADMIN creates/edits/deactivates packs; USER reads them. Writes use guarded SQL commands and optimistic versions. Pack photos are re-encoded and stored privately, served through short-lived signed URLs. The mobile Packs menu supports catalogue editing and photos.

Apply 202609140024_packs.sql to the hosted database before deploying the matching API. No database reset is needed. Migration 024 was applied through the owner’s SQL Editor. Remote checks verified packs, pack_items and the private pack-images bucket.

Existing appointment payments support full or partial receipts and prevent overpayment. Flutter now explains the remaining credit and offers a full-payment shortcut. This is debt owed by the client, not a refundable wallet balance.

Remaining work: client pack purchase snapshots, consumption of individual sessions through appointments, pack-specific payment allocation and consolidated client credit. Catalogue packs must not yet be treated as purchased entitlements or automatically billed appointments. Existing appointment receipts are unchanged.
