# 18 — Future Enhancement Recommendations

Recommendations are grouped by impact and grounded in the actual current state of the codebase. Each item lists a justification, an outline of changes, and a rough effort estimate.

## Tier 1 — Blocking for production readiness

### F-01 Configure a production Android signing key
**Why:** Today the release build is signed with the debug keystore (see S-01). Play Store will reject this.
**Where:** `android/app/build.gradle.kts`, new `android/key.properties`.
**Effort:** ~1 day including initial Play Console upload.

### F-02 Server-side OTP verification + attempt counter
**Why:** OTP is currently verified client-side (`BookingService.startTrip`) with no lockout (S-06). A malicious driver client could brute force.
**Outline:** Move verification into a callable Cloud Function (`verifyRideOtp({bookingId, otp})`) that reads the booking, compares the OTP, increments a counter on miss, and locks the booking after N misses. Driver client calls the function instead of writing directly.
**Effort:** ~2 days incl. tests.

### F-03 Driver push notifications on new bookings
**Why:** Today only riders get pushes (`onBookingCreated`). Drivers rely on Firestore live streams, which won't wake a backgrounded / killed app.
**Outline:** Same trigger function — look up `users/{driver.driverId}.fcmToken` and push a high-priority notification. Optional: add `RIDE_REQUEST` payload type and a deep-link to `/driver-booking-dashboard`.
**Effort:** ~1 day.

### F-04 Tighten `users` update rule with a field whitelist
**Why:** See S-04 — current rule blocks privilege escalation but allows arbitrary other field writes.
**Effort:** ~½ day plus emulator-test additions.

### F-05 Rotate the Firebase Admin SDK service-account key
**Why:** Historical exposure in git history (see S-02). Even after `01b0d30` removed the file, the key is still valid until rotated.
**Effort:** ~½ hour, but coordinate with anyone using the key for one-off scripts.

## Tier 2 — Strong UX / engineering improvements

### F-06 Online payment integration (UPI/Razorpay)
**Why:** `PaymentMethod` enum exposes `upi`, `card`, `wallet`, `netBanking`, but only `cash` works end-to-end. Razorpay or PhonePe gateway gives instant settlement and reduces driver cash-handling.
**Outline:** Razorpay Flutter SDK + a `paymentProvider` to drive the booking confirmation sheet. New Cloud Function endpoint to verify the order signature server-side, then update `paymentStatus`.
**Effort:** ~5–7 days incl. PCI compliance review.

### F-07 Booking status pushes (driver arriving, started, completed)
**Why:** Riders today only get OTP push; status changes are reflected only via in-app stream subscriptions.
**Outline:** Add an `onBookingStatusChanged` Cloud Function on `bookings/{id}` write that compares old vs new status and pushes a templated notification to the rider.
**Effort:** ~2 days.

### F-08 Scheduled `expireOldBookings` Cloud Function
**Why:** Today this method exists in `BookingService` but is a client no-op without `adminOverride`. Without a server job, stale pending bookings accumulate.
**Outline:** Cloud Scheduler → Cloud Function every 5 minutes; runs the same query, flips status to `expired`.
**Effort:** ~½ day.

### F-09 Switch driver-rating aggregation to a Firestore counter doc
**Why:** `BookingService._updateDriverRating` does a full query of the driver's vehicles on every rating. Cheap today; not cheap at scale.
**Outline:** Maintain `drivers/{uid}/stats/aggregate` with `ratingSum, ratingCount, totalTrips` via a Cloud Function trigger. The mobile client reads the single doc.
**Effort:** ~1 day.

### F-10 Push payload as JSON, structured deep-links
**Why:** Foreground decoder is fragile (S-09) and there's no consistent deep-link scheme.
**Outline:** Adopt `dart:convert.json` for `RemoteMessage.data` and a single `route` key the app uses to call `context.goNamed(...)` after notification tap.
**Effort:** ~1 day.

### F-11 Rules-emulator unit tests
**Why:** Highest-ROI defence against rule regressions. Today there are none.
**Outline:** `firebase emulators:start`, `@firebase/rules-unit-testing`, Mocha. Cover: `isAdmin` self-escalation, verification-status state machine, completed-booking field locks, driver-location stalking.
**Effort:** ~2 days for ~30 tests.

### F-12 Sign-out cleanup
**Why:** `AuthService.signOut` doesn't clear local Firestore cache or call `removeFcmToken` / topic unsubscribes. Stale data and unwanted notifications persist for the next user.
**Outline:** Compose an `AuthFlowController` notifier that orchestrates token removal, topic unsubscribes, `clearPersistence`, and Firebase sign-out.
**Effort:** ~½ day.

## Tier 3 — New features (product expansion)

### F-13 In-app chat between rider and driver
**Outline:** `chats/{bookingId}/messages/{msgId}` subcollection scoped to the booking participants. Rules: read+create by either participant; trip-locked after `completed`.
**Effort:** ~5 days.

### F-14 Multi-language support (Bengali, Hindi, Tamil)
**Why:** The Indian-market focus and presence of `bengali_calendar.dart` suggest non-Latin scripts. Today UI strings are inline English in screens.
**Outline:** `flutter_localizations`, ARB files, `intl: ^0.20.2` (already a dependency). Replace hardcoded strings.
**Effort:** ~5 days + per-language translation.

### F-15 Scheduled / pre-booked rides
**Why:** Booking model has `scheduledAt` and `isScheduled` already. UI to set them and a Cloud Scheduler to dispatch at the right time would unlock the feature.
**Effort:** ~3–5 days.

### F-16 Surge pricing
**Why:** `FareCalculator` already supports `isNightTime` / `isPeakHour` surcharges, but doesn't apply dynamic supply/demand surge.
**Outline:** Cloud Function periodically writes a `surge/{city}` doc with a multiplier; client applies it during fare estimation.
**Effort:** ~3 days for a basic implementation.

### F-17 Driver earnings dashboard with charts
**Outline:** `fl_chart` or `syncfusion_flutter_charts`. Compose data from `BookingService.getDriverStats` plus aggregate doc (F-09).
**Effort:** ~3 days.

### F-18 In-app refunds workflow
**Outline:** Rider can request refund on a completed/cancelled booking; admin approves; Cloud Function writes `paymentStatus = refunded` and triggers gateway refund call.
**Effort:** ~5 days, dependent on F-06.

### F-19 Multi-stop ride bookings (already partly modelled)
**Why:** `Booking.stops` exists but no UI wires it up.
**Effort:** ~3 days.

### F-20 Driver document expiry reminders
**Why:** `users/{uid}.drivingLicenseValidUpto` is stored but never read for reminders.
**Outline:** Scheduled Cloud Function checking dates within 14 days; FCM push to the driver.
**Effort:** ~1 day.

## Tier 4 — Engineering hygiene

### F-21 Multi-environment Firebase setup (dev / staging / prod)
**Outline:** See `docs/13-environment-configuration.md` § "Multi-environment strategy".
**Effort:** ~2 days.

### F-22 CI pipeline with coverage, analyze, integration tests
**Outline:** GitHub Actions matrix: `flutter analyze`, `flutter test --coverage`, optional `flutter test integration_test/` on macOS runners. Upload to Codecov.
**Effort:** ~1 day initial; ongoing cost is low.

### F-23 Centralise Firebase emulator config + npm scripts in `functions/`
**Outline:** `firebase emulators:exec` + npm scripts that spin up emulators and run a Mocha rules-test suite. Enables fast local feedback for both rules and functions.
**Effort:** ~1 day.

### F-24 Adopt v2 Functions SDK uniformly
**Why:** `functions/index.js` uses v2 (`onDocumentCreated`), `functions/feedback-suggestion-fun.js` uses v1 (`functions.https.onCall`). Mixing causes confusion.
**Effort:** ~½ day.

### F-25 Switch analytics to event-level (booking_created, booking_completed, cancellation_charged)
**Why:** Today only `sign_up` / `login` fire. Product analytics need the full funnel.
**Outline:** Centralise via an `AnalyticsService` and emit events alongside state transitions in `BookingService`.
**Effort:** ~2 days.

### F-26 Replace `print` with `AppLogger` exhaustively (already mostly true)
**Check:** Search for any stray `print(...)` calls in `lib/`. The current code is mostly clean (`TestMode.logTestMode` uses `print` deliberately for the banner). Document this exception in `AppLogger`.
**Effort:** ~½ day.

### F-27 Audit `users` document for unused fields
**Why:** Reader normalises `fullName`/`userName`/`name`, `phoneNumber`/`mobile`. The codebase is in flux about which name is canonical. Pick one and migrate.
**Effort:** ~1 day + a one-shot migration script (`functions/updateAllUsers.js` already exists as a template).

## Tier 5 — Long-horizon / aspirational

### F-28 Native maps and in-app routing
Today the codebase uses `geolocator` + `geocoding` but **no Google Maps Flutter** widget — the live tracking screen presumably shows a basic visualisation. Adopting `google_maps_flutter` would unlock proper map UI and polyline route preview.

### F-29 Background location for drivers
iOS background location requires entitlement + careful battery design. Worth deferring until driver acquisition justifies the engineering investment.

### F-30 Web admin panel in this monorepo
The admin panel is a separate codebase today. Moving it into a `web/` Flutter target (sharing models from `lib/models/`) reduces drift between mobile and admin schemas.

### F-31 Bookkeeping / GST invoicing
A separate "invoicing" Cloud Function that, on `paymentStatus → completed`, generates a PDF receipt and stores it on Storage. Compliance value for fleet operators.

### F-32 Driver leaderboards and gamification
Use the `drivers/{uid}/stats` aggregate (F-09) to compute weekly leaderboards. Encourages driver retention.
