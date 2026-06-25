# Zyppi Ride Flutter Codebase Review — Revised

Review date: 2026-06-20  
Scope: Flutter/Dart application, Firebase rules and Functions, Android/iOS configuration, dependencies, and automated tests.  
Method: read-only code inspection plus `flutter analyze`, `flutter test`, and Functions ESLint. No application code was changed.

## Confirmed product scope

- Online payment gateway processing is a future feature and is **not part of the current release assessment**.
- Existing payment enums/fields should remain available for that future integration.
- The current product must calculate and preserve complete fare details.
- Completing a trip must not automatically mean payment was received.
- After completion, the assigned driver or vehicle owner should be able to manually record the amount received through a validated amount input.
- A manually recorded full payment may mark the booking paid; a partial receipt should retain an outstanding balance and must not be represented as fully paid.

## Executive summary

The project has broad product coverage and a usable feature-oriented folder structure, but it is **not production-ready**. The most urgent problem is a committed Firebase Admin private key. Several core ride flows also conflict with Firestore rules, so live location and trip completion are expected to fail in production. Trip completion currently marks payment completed even though payment collection has not been implemented; this contradicts the confirmed manual-receipt workflow. iOS lacks the Firebase configuration and privacy/capability setup required by the packages used by the app. Automated test volume is misleading: the default suite is red, and most passing tests exercise an in-memory fixture rather than application behavior.

Overall assessment: **high release risk**.

| Area | Assessment | Main reason |
|---|---:|---|
| Security | Critical | Committed Admin private key; overly broad vehicle/document reads |
| Booking correctness | Critical | Client writes and Firestore rules disagree |
| Current payment recording | High risk | Trip completion incorrectly marks payment paid; manual receipt workflow is absent |
| iOS readiness | Critical | Missing Firebase plist, privacy strings, push/background capabilities, real bundle ID |
| Architecture | Needs major work | 48k Dart LOC, multi-thousand-line screens, Firebase globals throughout UI/state |
| State/lifecycle | High risk | Uncancelled auth/message subscriptions and mixed state models |
| Testing | High risk | Default suite fails; no meaningful rules/service/widget coverage |
| Static quality | Fair | Production Dart is analyzer-clean; 59 informational findings are test-only |
| Functions | Fair | ESLint passes; deployment source is distinguishable, but obsolete scripts/credentials remain |

## Scope and repository profile

- 14,165 files across the requested directories, including generated/platform/dependency material.
- 48,022 lines of Dart under `lib/`.
- Largest files: `vehicle_registration_screen.dart` (2,023), `document_upload_screen.dart` (1,929), `track_booking_screen.dart` (1,528), `agreement_signing_screen.dart` (1,298), and `reserve_vehicle_screen.dart` (1,181).
- Firebase Auth, Firestore, Storage, Messaging, Analytics, App Check, and Functions are used.
- Riverpod is present, but direct Firebase singleton access and local `setState` remain pervasive (104 direct `FirebaseAuth.instance`/`FirebaseFirestore.instance` references).

## Critical findings

### C1. Firebase Admin private key is committed

`functions/zyppiride-2025-firebase-adminsdk-fbsvc-8888785e38.json` contains a service-account private key, is tracked by Git, and has existed since commit `921c653`.

Impact: anyone with repository/history access can authenticate as the service account and bypass client-side Firebase rules within its IAM permissions.

Required response:

1. Disable/delete the key in Google Cloud IAM immediately and audit Cloud Audit Logs.
2. Create a replacement only if a non-Google runtime truly needs one; deployed Cloud Functions should use Application Default Credentials.
3. Remove the file from Git history, not only the current branch, and add credential patterns to `.gitignore` and secret scanning.
4. Rotate any other credentials that may have been handled by the obsolete scripts in `functions/`.

### C2. Live location cannot pass Firestore rules

The service writes `bookings.driverLocation` and `drivers.currentLocation` in `lib/services/live_location_service.dart:147-159`. Driver booking updates are restricted to a field list that excludes `driverLocation` (`firestore.rules:166-173`), while driver-document updates allow flat `latitude`, `longitude`, `heading`, `speed`, `lastUpdated`, and `currentBookingId`, not `currentLocation` (`firestore.rules:197-200`). The service also calls `update()` for a driver document that may not exist, despite the rule comment describing a first-write create path.

Impact: tracking starts locally but every database update is caught and logged, leaving riders without live location.

Recommendation: choose one canonical location schema, write/create it atomically, align the rules exactly, verify booking ownership/current booking server-side, and add emulator rule tests for allowed and denied principals.

### C3. Trip completion incorrectly includes payment completion and is rejected by rules

`BookingService.completeTrip` writes `paymentStatus = completed` (`lib/services/booking_service.dart:503-507`) even though no payment has been collected or verified. The driver update allowlist also omits `paymentStatus` (`firestore.rules:166-173`), so Firestore rejects the entire completion update. The client stops location tracking before attempting completion (`lib/providers/booking_provider.dart:563-575`), leaving an in-progress trip with tracking stopped when the write fails.

Impact: core ride completion fails, state becomes inconsistent, and the data model would falsely report an unpaid ride as paid if rules were loosened without changing the client behavior.

Recommendation for the confirmed current scope:

1. Trip completion should finalize only ride status, completion timestamp, actual trip measurements, and calculated fare details.
2. Leave `paymentStatus` pending after trip completion.
3. Stop location tracking only after the completion write succeeds (or restore it after failure).
4. Present a separate **Record Payment Received** action for completed rides.
5. Allow only the assigned driver or vehicle owner to record the received amount.
6. Preserve existing gateway-oriented fields for future implementation, but do not use them to imply that payment processing currently exists.

### C4. New Google/phone users conflict with user-create rules

New Google/phone signup writes `isAdmin: false` (`lib/services/auth_service.dart:550-562`), while user creation explicitly rejects the presence of any `isAdmin` field (`firestore.rules:39-42`).

Impact: Firebase Auth account creation can succeed while Firestore profile creation fails, producing partially registered users.

Recommendation: omit privileged fields from client creates; assign defaults in trusted backend code or interpret absence as false. Add integration tests for every auth provider against the emulator.

### C5. Booking creation and fare/assignment integrity are client-controlled

Booking rules only require the presence of fields and `status == pending` (`firestore.rules:131-151`). They do not verify that the nested vehicle exists/is approved/online, the driver owns it, the requested driver matches the vehicle, fare values match trusted pricing, timestamps are server timestamps, ratings are bounded, or that the rider has no active booking. `BookingService.createBooking` performs reads and calculations on a modifiable client (`lib/services/booking_service.dart:28-113`) without a transaction.

Impact: a modified client can create fraudulent fares/assignments, create concurrent active bookings, or send bookings to arbitrary user IDs. Driver rules also permit client changes to `fareDetails` without value constraints before completion.

Recommendation: create/accept/start/complete/cancel bookings in backend transactions with an explicit transition matrix and idempotency keys. Keep client rules narrow and validate every mutable field and range.

## High-severity findings

### H1. iOS target is not configured for the implemented features

- No tracked `ios/Runner/GoogleService-Info.plist` and `Firebase.initializeApp()` is called without generated options (`lib/main.dart:19-20`).
- Bundle ID remains `com.example.zyppiRide` in all app configurations (`ios/Runner.xcodeproj/project.pbxproj:371,550,572`).
- `Info.plist` has no location, camera, or photo-library usage descriptions despite `geolocator` and `image_picker` usage (`ios/Runner/Info.plist`). Missing descriptions cause permission access to terminate the app.
- No push notification capability/`aps-environment` entitlement or background modes are present, despite FCM and attempted live tracking.
- The Podfile does not explicitly state the deployment target even though the Xcode project uses iOS 13.

Recommendation: configure a real Apple bundle ID and Firebase iOS app, add the plist through the Runner target, add minimum required privacy strings, enable Push Notifications and appropriate Background Modes, decide whether genuine background location is required, and test on physical devices. App Store privacy manifests/disclosures must reflect location, identity, photos, analytics, and notification data usage.

### H2. Sensitive vehicle/identity material is readable too broadly

Any authenticated user can read every vehicle document and every `vehicles/{id}/documents/*` record (`firestore.rules:72-90`). Any authenticated user can also read all profile and vehicle images in Storage (`storage.rules:6-20`). Vehicle/document records commonly contain registration and verification material.

Recommendation: separate public searchable vehicle projections from private owner/compliance documents. Limit document and private-media reads to owner/admin/explicit booking participants; issue short-lived backend URLs where needed. Add file size/content-type checks to user and support uploads, which currently lack them.

### H3. Firestore owner booking read uses a field the model never writes

Rules authorize vehicle owners using top-level `resource.data.vehicleId` (`firestore.rules:147-148`), but `Booking.toMap()` only writes the ID nested under `vehicle` and has no top-level `vehicleId` (`lib/models/booking_model.dart:639-677`).

Impact: the intended owner availability/read path cannot authorize unless legacy documents happen to contain the extra field.

Recommendation: standardize schema and migrate existing data; use `resource.data.vehicle.vehicleId` or deliberately persist an immutable top-level reference.

### H4. Auth and messaging subscriptions leak

Both booking notifiers call `FirebaseAuth.instance.authStateChanges().listen(...)` without retaining/cancelling the subscription (`lib/providers/booking_provider.dart:78-90` and the equivalent driver initializer). Their `dispose()` methods cancel booking streams only. Notification initialization registers `onMessage`, `onMessageOpenedApp`, and token-refresh listeners without handles or an idempotency guard (`lib/services/notification_service.dart:116-132,259-265`). Reinitialization can duplicate handlers and local notifications.

Recommendation: expose auth as a Riverpod stream, retain every manual subscription, cancel on dispose, and make notification initialization singleton/idempotent.

### H5. “Pagination” duplicates the first page

`BookingNotifier.loadBookingHistory` appends results but never passes a `lastDocument` cursor to `getUserBookings`; repeated loads append the same first 20 records. `hasMore` can stay true forever when the first page is full (`lib/providers/booking_provider.dart`, history loader).

Recommendation: store a stable Firestore cursor in state/repository, reset it with filters, deduplicate by booking ID, and test end-of-list behavior.

### H6. State transitions are race-prone

Accept/start/complete/cancel use a read followed by a separate write rather than a transaction (`lib/services/booking_service.dart:385-545`). Two devices or retries can pass the same stale status check. `DateTime.now()` is used for authoritative creation timestamps.

Recommendation: use backend transactions and server timestamps; define permitted from/to statuses, actor, required fields, and idempotency behavior.

### H7. Test mode collection names do not match Firestore rules

`TestMode` redirects to `e2e_test_*` top-level collections (`lib/core/constants/test_mode.dart:7-24`), but `firestore.rules` has no matches for these collections. Device tests against Firebase will be denied unless run with insecure/development rules, which invalidates security testing.

Recommendation: use Firebase emulators with the production rules and deterministic test users/data; do not create a parallel unruled schema.

### H8. Manual payment-receipt workflow is not implemented

The current application retains gateway-oriented concepts (`PaymentMethod`, `PaymentStatus`, and `paymentTransactionId`) but provides no reliable workflow for the driver/owner to record money actually received. A generic `updatePaymentStatus` method exists, but it does not verify the booking actor, completed status, received amount, previous receipts, or outstanding balance (`lib/services/booking_service.dart:591-614`). It is also not connected to the intended driver/owner amount-entry UI.

Recommended current workflow:

1. Show the immutable final calculated fare on a completed ride.
2. Show amount already received and remaining amount.
3. Provide a numeric **Record Payment Received** input to the assigned driver/vehicle owner.
4. Validate that the amount is positive and does not exceed the outstanding amount unless overpayment is an explicit business rule.
5. Record the authenticated actor and server timestamp.
6. Mark payment fully paid only when cumulative received amount reaches the final fare; otherwise retain a pending/outstanding state.
7. Prevent a payment-receipt update from changing fare, route, participants, vehicle, or ride status.

Suggested minimum fields, while retaining future gateway fields:

```text
amountReceived
remainingAmount
paymentReceivedAt
paymentReceivedBy
paymentRecordedManually
paymentStatus
```

If multiple or partial receipts must be supported, a receipt subcollection is safer than repeatedly overwriting one amount because it provides an audit trail. If only one full cash receipt is supported, require the entered amount to match the final fare and keep the model simpler.

## Medium-severity findings

### M1. Architecture and maintainability

Screens combine presentation, validation, Firestore access, uploads, navigation, and business decisions. Five screens exceed 1,100 lines and two exceed 1,900. State management is split among Riverpod, direct Firebase calls, singleton services, and local `setState`. This makes behavior difficult to test and rule/client contracts easy to drift.

Recommended target structure per feature: presentation widgets/controllers, immutable state, domain use cases/entities, and data repositories/data sources. Inject Auth/Firestore/Storage abstractions. Break large screens into focused widgets and move workflows out of widgets.

### M2. Error handling hides actionable failures

Services frequently catch broad exceptions and return `null`, `false`, or empty lists. A missing index, permission denial, parsing defect, and legitimate empty result become indistinguishable. Some UI errors expose raw exception strings (`role_selection_screen.dart:115-118`). There is no production crash reporting/observability dependency.

Recommendation: use the existing typed `Result`/exception layer consistently, preserve error categories, show safe user messages, and report sanitized failures to Crashlytics or another production telemetry system.

### M3. Notification and logout lifecycle is incomplete

FCM token storage exists, but `AuthService.signOut()` does not remove the token or unsubscribe role/user topics (`lib/services/auth_service.dart:506-517`). Shared devices can retain prior-user targeting. Client subscription to `user_<uid>` topics should not be treated as confidential authorization because topic names are guessable and clients control subscriptions.

Recommendation: send private notifications directly to backend-managed tokens, remove tokens and subscriptions during logout/account changes, and maintain multi-device token records rather than one `fcmToken` field.

### M4. Background tracking implementation is expensive and not actually background-capable

During a trip, a position stream and a five-second timer both request high-accuracy location (`lib/services/live_location_service.dart`). This can duplicate writes and materially drain battery. No iOS background capability or Android foreground service implementation is present.

Recommendation: use one adaptive stream, throttle/debounce based on movement and app lifecycle, add a foreground service only if product requirements justify continuous background tracking, and define retention/precision limits.

### M5. OTP and personal data are stored in the booking document

The ride OTP is generated on-device using `dart:math`, stored in the rider/driver-readable booking, included in FCM data, and displayed as fallback. It is suitable only as a lightweight ride handoff check, not a security credential. Booking documents duplicate phone/name and exact locations.

Recommendation: generate/verify OTP server-side, store a short-lived hash, rate-limit attempts, expire it, and minimize/expire personal and location data according to a retention policy.

### M6. Dependency and release hygiene

`flutter analyze` reports 91 packages with newer versions incompatible with constraints. Some declared direct versions are old while resolution floats much newer through caret ranges. The package description is still the Flutter template and version is `1.0.0+1`. Functions contains multiple obsolete variants (`index-1.js`, `.old`, mail scripts, admin update scripts) alongside production `index.js`.

Recommendation: establish scheduled dependency updates, document supported Flutter/Dart versions, remove/archive non-deployable scripts, keep operational migration scripts outside deploy source, and enforce reproducible CI builds.

### M7. Accessibility, localization, and design consistency

User-facing strings are hard-coded in English across large widgets, styling is repeated, and global theme coverage is shallow. Semantic labels appear in places but there is no systematic accessibility or text-scaling test strategy.

Recommendation: introduce Flutter localization, design tokens/component themes, semantic audits, large-text/golden tests, and contrast/tap-target checks.

## Validation results

### Static analysis

Command: `flutter analyze`  
Result: failed exit status because 59 informational lint findings exist, all in integration-test/report code (`avoid_print` and non-lowerCamelCase test identifiers). No production Dart warning/error was reported.

This is a useful baseline but the lint policy is minimal (`flutter_lints` defaults only). CI should treat analyzer output consistently and add rules around discarded futures, imports, public APIs, and package boundaries as the architecture is refactored.

### Unit/widget tests

Command: `flutter test`  
Result: **50 passed, 1 failed**.

- The 50 passing tests validate a custom in-memory mock and seeded records. They do not invoke production repositories/services, Firebase emulators, or security rules.
- `test/widget_test.dart` is the original counter template. It pumps `MyApp` without `ProviderScope`, then asserts counter widgets that do not exist, causing both a Riverpod exception and assertion failure.
- No meaningful production unit tests were found for fare calculation, model serialization, booking state transitions, auth provisioning, pagination, location lifecycle, or notification lifecycle.

### Cloud Functions lint

Command: `npm --prefix functions run lint`  
Result: passed.

There are no Functions unit/emulator tests. The deployed `index.js` booking trigger and admin seed endpoint therefore have no automated behavior/security coverage.

## Positive observations

- Production Dart currently compiles through static analysis without warnings/errors.
- App Check is activated with release providers differentiated from debug/profile (`lib/main.dart:26-38`).
- Logging is centralized and disabled by default in release builds.
- Firestore rules attempt field allowlists, admin checks, booking participant reads, and restricted notification writes rather than using blanket access.
- Storage vehicle uploads enforce image type and a 5 MB limit.
- Cloud Functions admin endpoint verifies both ID token and admin status.
- Most async widget workflows include `mounted` checks, and many controllers/timers are disposed correctly.
- Functions lint and Android release minification/signing structure are present.

## Recommended remediation plan

### Phase 0 — immediate incident response (today)

1. Revoke the committed service-account key and audit its use.
2. Remove it from Git history; enable repository secret scanning.
3. Freeze production deployment until booking/rules contract tests pass.

### Phase 1 — restore core correctness (1–3 days)

1. Define one booking schema and explicit state-transition matrix.
2. Separate ride completion from payment receipt: completion calculates/finalizes fare and leaves payment pending.
3. Implement validated manual receipt recording for the assigned driver/owner, including received and remaining amounts.
4. Move create/accept/start/complete/cancel and OTP verification to trusted transactions/Functions.
5. Align live-location schema, rules, and create/update behavior.
6. Fix Google/phone user provisioning and owner booking reads.
7. Add emulator tests proving authorized and unauthorized rule behavior, including payment receipt field restrictions.

### Phase 2 — make iOS build/release viable (1–2 days plus Apple setup)

1. Configure bundle ID, Firebase plist, signing, APNs, entitlements, and background modes.
2. Add privacy usage descriptions and verify every permission on physical iOS devices.
3. Validate Google Sign-In URL schemes and Firebase phone-auth/APNs setup.
4. Complete App Store privacy disclosures and retention policy review.

### Phase 3 — establish a trustworthy quality gate (3–7 days)

1. Replace the template test and test `main()` through an injectable bootstrap.
2. Unit-test fare/model/state logic; widget-test auth, booking, error, and role flows.
3. Test full, partial, duplicate, excessive, unauthorized, and pre-completion payment receipt attempts.
4. Run Firebase emulator integration/rules tests in CI.
5. Add Android/iOS build checks, Functions lint/tests, secret scan, and analyzer gates.

### Phase 4 — reduce engineering cost (incremental)

1. Refactor the largest screens feature by feature into controller/use-case/repository boundaries.
2. Standardize Riverpod state and dependency injection; remove Firebase globals from UI.
3. Fix cursor pagination, subscription ownership, notification logout, and typed error propagation.
4. Add localization, design tokens, accessibility tests, telemetry, and performance profiling.

## Release gate

Do not release until all critical findings are closed, iOS capabilities/privacy configuration is verified on a physical device, the default test suite is green, and emulator tests prove the booking lifecycle and Firebase rules agree. For the current scope, trip completion must leave payment pending until a driver/owner records the received amount, and that update must be field-restricted and tested. A payment gateway is not a release requirement. The exposed key must be revoked even if the repository is private.
