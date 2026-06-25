# Zyppi Ride — Full Codebase Review with Explanations

Review date: 20 June 2026  
Reviewed areas: Flutter application, Firebase integration and rules, Cloud Functions, booking lifecycle, authentication, live location, notifications, Android/iOS configuration, dependencies, architecture, and tests.  
Code changes: none. This document is an assessment and implementation plan only.

## 1. Executive assessment

Zyppi Ride already contains a large amount of product functionality: multiple authentication methods, user and driver roles, vehicle registration and verification, booking, fare calculation, ride status management, live location, notifications, saved addresses, offers, schedules, support flows, and integration-test infrastructure.

The production Dart source passes static analysis without errors or warnings. That means the project is syntactically healthy and type-correct. It does **not**, however, mean that all features will work against Firebase or that the app is ready for App Store release.

The main risks occur where different parts of the system disagree:

- Flutter writes fields that Firestore rules reject.
- Authentication creates data that the user rules prohibit.
- Trip completion is mixed with payment completion even though payment processing is not implemented.
- iOS uses packages requiring permissions and capabilities that the Xcode target does not contain.
- Many tests validate mock data rather than production behavior.

Current release assessment: **high risk; not production-ready**.

## 2. Confirmed payment scope

Online payment processing is a future plan. It should not be removed, but it should not be presented as implemented.

The intended current behavior is:

1. The app calculates the complete fare breakdown.
2. The driver completes the ride.
3. Ride completion finalizes the fare but leaves payment pending.
4. The driver or vehicle owner enters the amount actually received.
5. The app records who entered it and when.
6. Payment becomes paid only when the full fare has been received.

Existing future-facing fields such as `PaymentMethod`, `PaymentStatus`, and `paymentTransactionId` can remain. They should be separated from the current manual receipt workflow.

Suggested current receipt fields are:

```text
amountReceived
remainingAmount
paymentReceivedAt
paymentReceivedBy
paymentRecordedManually
paymentStatus
```

If partial or multiple payments are required, a receipt subcollection is preferable because every receipt remains auditable. If only one full cash receipt is supported, the simpler option is to require the entered amount to equal the final fare.

## 3. Review scorecard

| Area | Rating | Explanation |
|---|---:|---|
| Credential security | Critical | A Firebase Admin private key is committed to Git |
| Firebase authorization | Critical | Important client writes do not match Firestore rules |
| Booking lifecycle | Critical | Completion, location, and actor rules are inconsistent |
| Manual payment recording | High | Required workflow is absent; current code marks unpaid rides paid |
| iOS readiness | Critical | Firebase, permissions, push, and bundle configuration are incomplete |
| Architecture | High maintenance risk | 48,022 Dart lines with several very large, mixed-responsibility screens |
| Automated tests | High risk | Default suite fails and most passing tests use an in-memory fixture |
| Static Dart quality | Good baseline | Production Dart is analyzer-clean |
| Cloud Functions | Fair | Lint passes, but tests and source hygiene are incomplete |

## 4. Critical findings

### 4.1 Firebase Admin private key is exposed

The tracked file `functions/zyppiride-2025-firebase-adminsdk-fbsvc-8888785e38.json` contains a service-account private key. It has been present since the initial Git commit.

Why this matters: a normal Firebase client configuration identifies an app and is protected by Auth, App Check, and rules. An Admin credential can operate with the service account's IAM permissions and bypass client rules. A private repository reduces exposure but does not make a committed private key safe.

Deleting only the current file is insufficient because Git history retains the secret.

Required action:

1. Revoke/delete the key in Google Cloud IAM immediately.
2. Review Cloud Audit Logs for use of that service account/key.
3. Remove the secret from all Git history.
4. Add secret scanning and credential patterns to repository protections.
5. Use Application Default Credentials in deployed Cloud Functions.

This is the first action to complete because other engineering improvements cannot compensate for an active leaked Admin credential.

### 4.2 Live location writes are rejected

`LiveLocationService` writes a nested `driverLocation` field to the booking and a nested `currentLocation` object to the driver document. Firestore rules allow neither shape. Driver rules instead allow a different set of flat fields.

Why this is difficult to notice: the service catches the Firestore exception and logs it. Location permission may succeed and the local stream may start, so the driver-facing UI can appear operational while the database receives no usable location.

User impact:

- Passenger cannot track the driver.
- Driver may believe tracking is enabled.
- Support receives intermittent “location not updating” complaints.
- Repeated failed writes consume device/network resources.

Required design decision: define one canonical location document shape. Then align the service, model, security rules, queries, and cleanup behavior to it. Tests must prove that only the assigned driver can write and only the current passenger/driver/admin can read.

### 4.3 Trip completion is coupled to a nonexistent payment process

`BookingService.completeTrip` sets both booking status and `paymentStatus = completed`. No payment has been collected or verified at that point. Firestore driver rules also exclude `paymentStatus`, causing the complete-trip write to fail.

The provider stops location tracking before attempting this write. If Firestore denies it, the booking stays in progress while tracking has already stopped.

Correct current behavior:

- Complete the ride.
- Calculate/finalize fare details.
- Keep payment pending.
- Stop tracking after successful completion.
- Separately allow the driver/owner to record money received.

Payment gateway processing remains future scope and is not required to close this issue.

### 4.4 Google and phone signup can leave incomplete accounts

New Google/phone profiles include `isAdmin: false`. Firestore user-create rules reject any client-created `isAdmin` field, regardless of whether it is false.

The Firebase Auth account can therefore be created while the Firestore profile fails. The user becomes logged in without the profile data required for role selection and routing.

Fix: omit privileged fields entirely from client profile creation. Backend/admin logic should set privileged values. Test email, phone, and Google registration individually against Firebase Emulator rules.

### 4.5 Booking creation trusts values controlled by the passenger's device

The mobile client chooses the vehicle/driver, calculates fare, applies promotion information, generates the ride OTP, and writes the booking. Firestore rules mostly check that required fields exist and status is pending.

A modified client could potentially submit:

- A manipulated fare or discount
- An unavailable/unapproved vehicle
- A driver who does not own the vehicle
- Unrealistic distance/duration
- Multiple simultaneous active bookings
- Client-generated timestamps or assignment data

Fare display can remain in Flutter for responsiveness, but authoritative booking creation should recalculate and validate fare in a trusted transaction or Cloud Function.

## 5. High-severity findings

### 5.1 Manual receipt recording needs a dedicated contract

The existing generic payment-status method accepts a status but does not verify:

- That the caller is the assigned driver or vehicle owner
- That the ride is completed
- The received amount
- Existing received/remaining values
- Duplicate submissions
- Whether the amount exceeds the outstanding fare

The recommended completed-ride UI is:

```text
Final fare:       ₹850
Already received: ₹500
Remaining:        ₹350
Status:           Pending

[ Record Payment Received ]
```

The amount dialog should use a numeric keyboard and display final fare, previously received amount, and remaining amount. Firestore rules should permit changes only to receipt-related fields. Receipt entry must never be able to change fare, participants, route, vehicle, or ride status.

### 5.2 iOS is not configured for current app capabilities

The iOS target has no tracked `GoogleService-Info.plist` while Firebase is initialized without explicit generated options. The bundle identifier is still `com.example.zyppiRide`.

`Info.plist` also lacks the privacy descriptions required by location, camera, and photo APIs. iOS can terminate an app when it accesses a protected API without the required description.

Push notification and background capabilities are also absent even though the app uses Firebase Messaging and continuous driver tracking.

Before iOS release:

1. Register the real bundle ID with Apple and Firebase.
2. Add the matching Firebase plist to the Runner target.
3. Configure APNs and Push Notifications capability.
4. Add only the background modes genuinely required by the product.
5. Add location, camera, and photo-library usage descriptions.
6. Configure Google Sign-In URL handling if Google login remains enabled.
7. Test authentication, notification, image selection, and location on physical devices.

### 5.3 Private vehicle and verification information is too broadly readable

Every authenticated user can read all vehicle documents and vehicle document subcollections. Authenticated users can also read all profile and vehicle images in Storage.

Public marketplace details and private compliance documents should not share the same access boundary. Registration certificates, licenses, insurance, or verification material should normally be limited to the owner and administrators.

Recommended separation:

- Public/searchable vehicle projection
- Private owner data
- Private verification/compliance data
- Booking-specific participant data

### 5.4 Owner booking authorization references the wrong field

Firestore rules check a top-level `booking.vehicleId`. The Flutter booking model writes the ID at `booking.vehicle.vehicleId`.

Consequently, the intended rule allowing the vehicle owner to read relevant bookings cannot authorize newly written records through that condition.

Fix one schema and migrate old documents if required. Do not support two shapes indefinitely.

### 5.5 Auth and notification listeners are not fully disposed

Booking notifiers listen to authentication changes without retaining the subscriptions. Their disposal logic therefore cannot cancel them. Notification setup similarly creates message/token listeners without an idempotency guard or cancellation handles.

Possible symptoms include duplicate notifications, duplicate data loads, updates after provider disposal, and memory leaks.

Use Riverpod stream providers where possible. Otherwise retain and cancel every `StreamSubscription`, and make notification initialization safe to call only once.

### 5.6 Booking-history pagination repeats the first page

The provider appends booking results but does not retain/pass the final Firestore document cursor. Loading more can therefore fetch the same first page repeatedly and append duplicates.

Fix: store a cursor with the state, use `startAfterDocument`, reset it when filters change, and deduplicate results by booking ID.

### 5.7 Booking status changes are race-prone

Accept, start, cancel, and complete generally perform a read followed later by a write. Another device can change the record between those operations.

Examples include acceptance and cancellation occurring simultaneously or the same completion being submitted twice.

Use backend/Firestore transactions with a defined transition matrix specifying actor, current status, next status, required fields, and idempotency behavior.

### 5.8 E2E test collections do not match production rules

E2E mode redirects data to `e2e_test_*` collections, but production Firestore rules contain no matches for those collections. Tests against Firebase will either fail or require relaxed rules, which means they do not validate production security.

Use Firebase Emulator Suite with the real rules and isolated emulator data instead.

## 6. Medium-severity findings

### 6.1 Architecture is expensive to change safely

The app contains 48,022 Dart lines. Several screens exceed 1,000 lines, with vehicle registration and document upload approaching 2,000 lines. These files mix UI, validation, Firebase calls, uploads, navigation, and business rules.

Riverpod is present, but direct Firebase singleton access and `setState` remain common. This inconsistency makes dependency replacement and unit testing difficult.

Refactor incrementally, starting with booking and authentication:

```text
feature/
  presentation/  screens, widgets, providers/controllers
  domain/        entities and use cases
  data/          repositories, DTOs, Firebase data sources
```

A full rewrite is not recommended. Move one workflow at a time behind tested repository/use-case boundaries.

### 6.2 Broad exception handling hides the actual failure

Many services catch every exception and return false, null, or an empty list. Permission denial, missing Firestore index, network failure, parsing failure, and genuinely empty data then look identical to callers.

Use the existing typed result/error infrastructure consistently and add production crash/error telemetry. User messages should be safe and understandable; raw Firebase exceptions should remain in sanitized diagnostics.

### 6.3 Notification ownership is incomplete on logout

Token storage exists, but authentication logout does not reliably remove the FCM token or unsubscribe prior role/user topics. On a shared device, a later user could receive notifications intended for the previous account.

Private notifications should be sent to backend-managed device tokens, not treated as secure merely because they use a guessable user topic name.

### 6.4 Location tracking may drain battery

The service uses both a high-accuracy position stream and a five-second timer requesting another current position. This duplicates work and writes. It also does not implement the platform service/capability setup required for reliable background tracking.

Use one adaptive stream, throttle updates according to movement, define foreground/background requirements explicitly, and retain only the precision/history needed by the product.

### 6.5 Ride OTP is a lightweight handoff check, not secure verification

The OTP is generated on the client, stored in a booking readable by the participants, and included in FCM data. It should not be treated as a high-security credential.

If stronger assurance is required, generate and verify it server-side, store a short-lived hash, limit attempts, and expire it. Exact locations, phone numbers, and OTP data should also have a retention policy.

### 6.6 Dependency and repository hygiene need maintenance

Dependency resolution reports 91 newer versions incompatible with current constraints. This does not require an immediate mass upgrade, but upgrades should be scheduled and tested rather than deferred indefinitely.

The Functions directory also contains obsolete/alternative scripts beside the deployed `index.js`. Operational scripts should be separated from deployable Functions source to reduce accidental deployment and credential handling.

### 6.7 Localization and accessibility are incomplete

Most strings and styles are hard-coded. There is no systematic localization, text-scaling, screen-reader, contrast, or tap-target test strategy.

Introduce localization resources and shared design tokens, then test critical screens with large text and semantics enabled.

## 7. Automated validation results

### Flutter analysis

`flutter analyze` found 59 informational findings, all in integration-test/report code. Production Dart produced no analyzer errors or warnings.

This confirms a good compile-time baseline, but static analysis cannot detect Firestore authorization mismatches or missing iOS runtime permissions.

### Flutter tests

`flutter test` resulted in **50 passed and 1 failed**.

The 50 passing tests primarily validate seeded in-memory mock collections. They do not exercise production services, Firestore rules, Riverpod behavior, or actual screens.

The failing widget test is the original Flutter counter template. It pumps `MyApp` without `ProviderScope` and searches for counter widgets that do not exist.

Important missing tests include:

- Fare calculations and rounding
- Booking serialization
- Booking status transitions
- Full/partial/manual payment receipt recording
- Unauthorized receipt attempts
- Google/phone/email user provisioning
- Firestore and Storage rules
- Pagination
- Live-location lifecycle
- Notification initialization/logout
- Critical widgets and navigation flows

### Cloud Functions

`npm --prefix functions run lint` passes. No meaningful Functions unit/emulator tests were found.

## 8. Positive engineering observations

- Production Dart is analyzer-clean.
- App Check distinguishes release providers from debug/profile providers.
- Logging is centralized and disabled by default in release builds.
- Firestore rules attempt least-privilege field allowlists instead of using blanket access.
- Vehicle image uploads enforce image type and a 5 MB maximum.
- The admin catalog endpoint validates both an ID token and admin status.
- Many asynchronous widget flows use mounted checks.
- Android release minification and signing structure are present.
- The existing fare model already provides a useful base for the confirmed current workflow.

## 9. Recommended implementation sequence

### Phase 0 — security incident response

1. Revoke the exposed Admin key.
2. Audit key/service-account activity.
3. Remove the secret from Git history.
4. Enable secret scanning.

### Phase 1 — restore core ride correctness

1. Define the canonical booking and location schemas.
2. Separate trip completion from payment receipt.
3. Make trip completion finalize fare while leaving payment pending.
4. Implement the manual driver/owner amount receipt workflow.
5. Align Firestore rules with these exact writes.
6. Fix Google/phone profile creation.
7. Fix owner booking authorization.
8. Use transactions/backend logic for booking transitions.

### Phase 2 — make iOS viable

1. Configure production bundle ID and Firebase app.
2. Add the Firebase plist and APNs setup.
3. Add privacy descriptions and required capabilities.
4. Test on physical iPhones.
5. Complete App Store privacy disclosures.

### Phase 3 — establish a trustworthy CI gate

1. Replace the counter-template test.
2. Add fare, model, provider, widget, and Functions tests.
3. Add Firebase Emulator rule tests.
4. Test manual receipt full, partial, duplicate, excessive, and unauthorized cases.
5. Run analyzer, tests, Android/iOS builds, Functions lint/tests, and secret scanning in CI.

### Phase 4 — reduce maintenance cost

1. Refactor booking into presentation/domain/data boundaries.
2. Refactor authentication next.
3. Split the largest screens.
4. Standardize Riverpod dependency injection.
5. Add typed errors, telemetry, localization, accessibility, and performance monitoring.

## 10. Release gate

The app should not be released until:

- The exposed Admin key is revoked and removed from history.
- Live location writes are authorized and tested.
- Trip completion succeeds without falsely marking payment paid.
- Driver/owner manual receipt recording is field-restricted and tested.
- Google/phone signup creates valid profiles.
- iOS Firebase, permission, push, and bundle configuration is complete.
- The default Flutter test suite passes.
- Emulator tests prove both allowed and denied Firebase operations.

An online payment gateway is explicitly **not** a release requirement at this stage. Correct fare calculation and secure manual payment-receipt recording are the present requirements.
