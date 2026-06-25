# 21 — Admin Panel Documentation

> **Important scope note**: the admin panel is a **separate web codebase** that is *not* present in this Flutter repository. This document specifies the contract between mobile and admin — the Firestore collections, fields, and Cloud Functions the admin panel reads from and writes to. A complementary list of admin requirements lives in `ADMIN_PANEL_REQUIREMENTS.md` at the repo root.

## Admin identity & authorisation

| Mechanism | Detail |
|---|---|
| Identity | Firebase Auth user with `users/{uid}.isAdmin == true` |
| How `isAdmin` is set | Manual write to Firestore (admin only). **Never settable from any client** — `firestore.rules` blocks any client write that includes the key. |
| Helper rule | `function isAdmin() { return request.auth != null && get(.../users/$(uid)).data.isAdmin == true; }` |
| App Check | App Check applies equally to the admin web app — register the Web app's reCAPTCHA v3 site key in Firebase Console |

## What admins can do in Firestore (server-permitted)

| Collection | Admin permissions (over and above per-actor rules) |
|---|---|
| `users/{uid}` | read (any), update (any — including `isAdmin`, `verificationStatus`, `verificationApprovedAt`, `verificationNotes`) |
| `vehicles/{id}` | update (any field — including `documentStatus`), delete |
| `bookings/{id}` | read (any), update (any — fare adjustments, refunds, payment status) |
| `complaints/{id}` | read (any), update (status changes, replies) |
| `feedbacks/{id}` | read (any) |
| `banners`, `offers`, `offer_banners` | full CRUD |
| `vehicleCatalog/{doc}` | write only via the admin-only `seedVehicleCatalog` HTTPS function |
| `metadata/vehicleSearchMeta` | the Cloud-Function path is preferred over direct writes |
| `drivers/{id}` | read (any) |
| `agreements/{id}` | read (any) — but immutable (no updates / deletes by anyone) |

## Required admin features (functional spec)

### 1. Driver verification queue

**Source data:** `users` where `verificationStatus == 'submitted'`, ordered by `createdAt` desc (composite index exists).

**Per-row actions:**
- Approve → `users/{uid}.verificationStatus = 'approved'`, `verificationApprovedAt = serverTimestamp()`.
- Reject → `users/{uid}.verificationStatus = 'rejected'`, `verificationNotes = '<reason>'`.
- Drill in → show user's vehicles (filtered by `userId`), their documents, and the signed agreement.

### 2. Vehicle document approval

**Source:** `vehicles` filtered by `userId == <driverUid>` and `documentStatus == 'pending'`.

**Per-row actions:**
- Approve → `vehicles/{id}.documentStatus = 'approved'`.
- Reject → `documentStatus = 'rejected'` + notes (consider a parallel `documentNotes` field — not currently in the schema; add via this admin workflow).

### 3. Live operations console

**Live online drivers:** query `vehicles` where `isOnline == true` (composite indexes available by city / type).

**Active bookings:** `bookings` where `status in ['pending', 'confirmed', 'driverArriving', 'arrived', 'inProgress']`.

**Stale bookings:** `bookings` where `status == 'pending'` AND `createdAt < now - 10 min`. (Today no scheduled function clears these — admin can manually expire by writing `status = 'expired'`.)

### 4. Booking detail / fare adjustment

Admins can edit any field on `bookings/{id}`, including `fareDetails` even after `status == 'completed'` (rule grants admins generic update access). Use cases: rider disputes, partial refunds, manual driver compensation.

**Refund flow** (manual, no online payment gateway yet):
1. Admin sets `paymentStatus = 'refunded'` or `'partialRefund'`.
2. If a payment gateway is later integrated, the refund must also be issued through the gateway.

### 5. Support center triage

**Complaints:** `complaints` where `status == 'Pending'`, ordered by `createdAt`. Allowed updates (admin-only per rules): `status`, plus any admin-extension fields you decide to add (e.g. `assignedTo`, `resolution`, `resolvedAt`).

**Feedback:** `feedbacks` — read-only for trend analysis. Filter by `rating <= 2` for negative-feedback follow-up.

### 6. Marketing CMS

| Collection | Admin actions |
|---|---|
| `banners` | create/update/delete with `{ imageUrl, title, subtitle, ctaUrl, isActive, priority, createdAt }` |
| `offer_banners` | similar to `banners` but with offer-specific link |
| `offers` | promo codes `{ code, discount (% of subtotal), description, isActive, expiryDate }`. `code` should be stored uppercase — `BookingService._getPromoDiscount` looks up by uppercase. |

### 7. Catalog management

Initial seed via `POST /seedVehicleCatalog` (admin Bearer-token auth, validated against `users/{uid}.isAdmin`). Subsequent edits today require either a code change + re-deploy, or a direct Firestore write to `vehicleCatalog/india2025`. **Recommended:** add an admin UI to edit the catalog map and write directly to that document, with a backup snapshot in `vehicleCatalog/india2025_backup_<ts>`.

### 8. Search-meta janitor

`metadata/vehicleSearchMeta.cities` and `vehicleTypes` are append-only via `arrayUnion` from the mobile client (`VehicleService._updateSearchMeta`). Over time, typos and duplicates may accrete. Admin should be able to edit the arrays directly to deduplicate / correct.

### 9. Analytics dashboards (recommended)

Surface key metrics by reading aggregate counts from Firestore (`.count()`):

| Metric | Query |
|---|---|
| Daily bookings | `bookings` where `createdAt >= today_start`, `.count()` |
| Completion rate | completed / (completed + cancelled) |
| GMV (Gross Merchandise Value) | sum `fareDetails.totalFare` for `status == 'completed'` |
| Top driver earnings | order by `users/{uid}.totalEarnings` (field not present today — add via Cloud Function aggregating completed bookings) |

### 10. Admin audit trail (recommended addition)

No built-in admin-action audit trail exists. Recommended addition: a Firestore-triggered Cloud Function on `users.isAdmin` and `users.verificationStatus` changes that writes an immutable record to `admin_audit/{ts}_{uid}` with `actorUid`, `targetUid`, `change`, `timestamp`. See [16 — Admin Manual](16-admin-manual.md) "Onboarding a new admin" for related governance.

## Admin actions exposed via Cloud Functions

| Function | Endpoint type | Notes |
|---|---|---|
| `seedVehicleCatalog` (`functions/index.js`) | HTTPS POST + Bearer ID token | Validates `users/{caller.uid}.isAdmin == true`. Writes `vehicleCatalog/india2025`. |
| `createComplaint`, `createFeedback` | HTTPS callable | Used by **end users**, not admins, but admins read the resulting docs. |
| (recommended) `bulkApproveVerifications`, `expireOldBookings`, `refundBooking` | new HTTPS callables | Centralise common admin ops with audit logging |

## Operational scripts (Node.js, not deployed)

These live in `functions/` and run with Admin SDK creds outside the Functions runtime. They are admin-only utilities, not consumer APIs:

| Script | Purpose |
|---|---|
| `functions/adminkeyypdate.js` | Bulk admin-flag updates |
| `functions/updateAllUsers.js` | Schema migrations on `users` |
| `functions/getFirestoreStructure.js` | Snapshot collection structure (dev tooling) |

**Auth for scripts:** Use Application Default Credentials (`gcloud auth application-default login`). **Never** download a service-account JSON key to disk; see incident in commit `01b0d30` and Finding S-02 in [11](11-security-audit-report.md).

## Mobile contract — what the admin panel must not change

To preserve mobile UX assumptions:

- **Do not rename `BookingStatus` string values.** They are stored as the enum's `.name` (camelCase) and parsed by `BookingStatus.fromString`. Renames will break in-flight bookings.
- **Do not relax `agreementId` format.** `firestore.rules` checks `agreementId.matches(uid + '_.*')` for ownership; changing this breaks driver onboarding.
- **Do not write to fields locked by rules** (e.g. you cannot write `paymentStatus` on a non-completed booking from the rider role). Admin rules grant override but staff should be aware they're using elevated privilege.
- **Do not delete user documents.** Rules currently don't forbid it explicitly, but cascading orphaned `vehicles`, `bookings`, `agreements`, `notifications` is the real concern. Build a soft-delete instead (`disabled: true`).
