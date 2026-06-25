# 27 — Firebase Cost Optimization Report

## Cost surface

Firebase bills primarily across these axes:

| Product | Billed unit |
|---|---|
| **Cloud Firestore** | document reads / writes / deletes, storage GB-month, network egress |
| **Cloud Storage** | storage GB-month, download bandwidth, operations |
| **Cloud Functions** | invocations, GB-seconds, network egress |
| **Cloud Messaging** | free for now (FCM does not bill per-message) |
| **Authentication** | free up to generous limits; phone auth bills per SMS sent |
| **App Check** | free |
| **Analytics** | free |

For Zyppi Ride at scale, **Firestore reads + Phone Auth SMS** will be the dominant line items. This report enumerates the hot paths and optimisation levers.

## Read-heavy hot paths (current code)

### 1. `LiveLocationService` driver-location writes (and reads via security rules)

**Write side** — `LiveLocationService._writeLocation` does one `update()` per `Position` event from `Geolocator.getPositionStream(distanceFilter: 10m)`. At 50 km/h that's ~1.4 writes/sec/driver. A 30-min city trip averages ~1,000–2,500 writes per driver per trip.

**Read side** — every rider snapshot fires the security rule, which itself performs **two extra document reads** (the booking doc + the helper rule). So one rider tracking one driver costs `1 + 2 = 3` reads per snapshot delivery.

**Cost impact (estimate):**
- 10,000 active trips/day × 1,500 writes ≈ 15M writes/day on `drivers` alone.
- 10,000 active trips/day × ~300 rider-side snapshots × 3 reads ≈ 9M reads/day.
- At Firestore unit price (~$0.06 per 100k writes, ~$0.06 per 100k reads), this alone is ~$15/day.

**Optimisations:**

| Lever | Saving |
|---|---|
| Increase `distanceFilter` from 10 m to 25 m | ~60 % write reduction |
| Throttle writes to at most one per 3 seconds even when moving fast | Caps writes/sec |
| Move location to **Realtime Database** instead of Firestore — RTDB is optimised for high-frequency tiny updates and prices by GB-transferred, not by operations | Often 10× cheaper for streaming GPS |
| Use a denormalised rider field (`bookings/{id}.driverLocation`) that the driver updates directly — saves the rule-read overhead | Eliminates the 2× rule-read penalty |
| Geohash + bucket reads on the dispatcher side | Trades index complexity for far fewer broad reads |

### 2. `BookingService.getUserStats` / `getDriverStats`

Both methods load **every completed booking** for the user/driver to sum `totalFare` and `estimatedDistance`. This is `O(history-size)` per dashboard view.

```dart
final completedBookings = await _bookingsRef
    .where('userId', isEqualTo: userId)
    .where('status', isEqualTo: 'completed')
    .get();   // ← every doc
```

**Cost impact:** a driver with 1,000 completed trips opening their dashboard incurs 1,000 reads per visit.

**Optimisation:** maintain an aggregate doc `users/{uid}/stats/aggregate` (or `drivers/{uid}/stats/aggregate`) updated by a Firestore trigger Cloud Function on each `bookings.status → completed`. Reads collapse from O(history) to 1.

### 3. `getActiveBookingStream`

Used by both rider and driver dashboards. The query uses `whereIn` with 5 status values; the field-override `bookings.status` ARRAY_CONTAINS index supports this. The cost is one read per snapshot delivery.

**Optimisation:** the stream is already efficient; ensure consumers wrap it in an `autoDispose` provider so it tears down when the user leaves the screen. Otherwise the subscription stays open indefinitely.

### 4. Vehicle search (`VehicleSearchService.searchVehicles`)

Reads up to `limit` vehicle docs (default 20) per search. Cheap per-search but called repeatedly as the rider tweaks filters.

**Optimisation:** debounce filter changes by ~300 ms on the UI side. Cache results in the provider keyed by the filter tuple.

### 5. Vehicle catalog (`vehicleCatalog/india2025`)

One large document, world-readable. Cached locally via `Source.cache` fallback in `VehicleService.fetchVehicleCatalog`. Once cached, costs nothing — but a cold start on a new install hits the server.

**Optimisation:** already well-handled. Could move to **Remote Config** to avoid Firestore reads entirely for this static data.

### 6. Composite-index storage

The repo defines ~24 composite indexes. Each composite index doubles the write cost on its collection (Firestore charges ~$0.018 per 100k composite-index writes in addition to the base write). For `bookings`, with 7 composite indexes, the per-write overhead is meaningful at scale.

**Optimisation:** periodically audit which indexes are actually used (Firebase Console → Firestore → Indexes shows usage stats) and remove unused ones.

## Write-heavy hot paths

### 1. `BookingService._updateDriverRating`

On every user rating, this method batch-updates **all** of the driver's vehicles. A driver with 5 vehicles incurs 5 writes per rating, even though all 5 carry the same denormalised average.

**Optimisation:** store the rating on the driver's user doc (`users/{uid}.rating`, `ratingCount`, `ratingSum`). Vehicles read the user's rating instead of carrying their own copy. One write per rating instead of N.

### 2. Driver online toggle batch

`DriverStatusService.toggleOnlineStatus` batch-updates `isOnline` on every vehicle + the user doc. Linear in vehicle count. Acceptable.

### 3. Search-meta `arrayUnion`

`VehicleService._updateSearchMeta` writes `metadata/vehicleSearchMeta` on every vehicle registration. arrayUnion-deduplicated, so the doc grows linearly with unique (city × type) pairs. Bounded — fine.

## Phone Auth SMS cost

Firebase Auth phone sign-in **bills per verified phone number** (rates vary by country; India is in the low-cost band but not free at scale).

**Optimisations:**
- Add a client-side **resend cooldown** (e.g. 30 s) to prevent accidental double-sends (S-03).
- Cache the verified phone number in `SharedPreferences` for some duration so returning users on the same device skip OTP and use Google/email if they re-link the account.
- For test accounts, register them as **Test phone numbers** in Firebase Console — no SMS sent.
- Use App Check + reCAPTCHA enforcement on phone auth to prevent SMS-bombing attacks.

## Cloud Functions cost

Current functions:

| Function | Trigger frequency | Avg. duration | Concern |
|---|---|---|---|
| `onBookingCreated` | once per booking creation | ~300 ms (one Firestore read + one FCM send) | Low |
| `seedVehicleCatalog` | once (manually) | ~500 ms | Negligible |
| `createComplaint`, `createFeedback` | per support submission | ~200 ms | Negligible |

Forecast: at 10k bookings/day, `onBookingCreated` runs 10k times. Even at 1 GB-sec each (the smallest meter), that's 10k GB-seconds/day — well within free tier.

**Optimisations:**
- Use **2nd-gen functions** uniformly. v2 supports concurrency (up to 1,000 concurrent requests per instance), reducing cold starts and bill.
- Set **minimum instances = 0** on rare functions; **= 1** on `onBookingCreated` if cold-start latency hurts OTP delivery time.
- For recommended additions (status-change pushes, dispatcher), batch FCM calls when targeting groups via `sendMulticast` to amortise overhead.

## Storage cost

- Vehicle images are capped at 5 MB each (storage rule). Driver with 10 vehicles × 5 images each = 250 MB upper bound.
- Profile photos go under `users/{uid}/...` — no size cap (gap noted in S-13 of [11](11-security-audit-report.md)). Tighten this rule before scale.

**Optimisations:**
- Compress images client-side. The codebase has `flutter_image_compress: ^2.1.0` — verify it's actually used before each `Storage` upload.
- Set **lifecycle rules** on Cloud Storage to delete signature images / receipt images older than X months if business requirements allow.
- Use **WebP** instead of JPEG for ~25 % smaller files.

## Network egress

Egress from Firestore / Storage to mobile clients is billed past a free threshold (~1 GB/day). For images, ensure:

- `cached_network_image` is used everywhere (it is).
- Set `Cache-Control: public, max-age=31536000` on Cloud Storage uploads so CDN edge caches kick in.
- Consider serving image variants (thumbnail / full) — generate via a Cloud Function or use Firebase Extensions "Resize Images".

## Quick wins (prioritised)

1. **Aggregate stats docs** (kills the worst `O(N)` reads for dashboards) — ~2 days.
2. **Increase live-location distance filter** to 25 m or move to RTDB — ~½ day for the simple fix.
3. **autoDispose Riverpod providers** for all `StreamProvider` consumers — ~½ day audit.
4. **Resend cooldown on phone auth** — ~½ day.
5. **Composite-index audit** in Firebase Console — ~½ day quarterly.
6. **Storage lifecycle rules** for old signature images — ~½ day.
7. **Cache-Control headers on Storage uploads** — ~½ day.

## Budget alerts

Set Firebase **budget alerts** in GCP Console at ₹X / month. Recommended: alerts at 50 %, 75 %, 90 %, 100 % of target.

Also enable **App Check enforcement** on Firestore and Storage to prevent unauthenticated scraping that would inflate read counts.

## Forecasting model (rough)

| Scale (active users) | Estimated monthly Firebase bill |
|---|---|
| 1,000 | <$50 |
| 10,000 | $300 – $700 |
| 100,000 | $4,000 – $9,000 (driven by live-location writes + reads + Phone Auth SMS) |
| 1,000,000 | $40,000+ (architecture changes needed — RTDB for location, BigQuery export for analytics) |

Exact figures depend on the rider-trip-per-user ratio and the driver-to-rider ratio. Treat as order-of-magnitude until you have a week of production data to extrapolate from.
