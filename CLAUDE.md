# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Run debug build
flutter run

# Run with E2E test mode (uses prefixed Firestore collections, skips OTP/email verification)
flutter run --dart-define=E2E_TEST_MODE=true

# Build release AAB for Play Store
flutter build appbundle --release

# Build release APK
flutter build apk --release

# Run unit tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Run integration tests
flutter test integration_test/

# Analyze code (lint)
flutter analyze

# Generate mocks (after adding @GenerateMocks annotations)
dart run build_runner build --delete-conflicting-outputs

# Deploy Firebase rules and functions
firebase deploy --only firestore:rules,storage
firebase deploy --only functions
firebase deploy --only firestore:indexes
```

## Architecture Overview

This is a Flutter ride-hailing app (Zyppi Ride) with two user roles: **Driver/Vehicle Owner** and **Customer/User**. The same binary serves both roles; the post-login route depends on the `role` field stored in the Firestore user document.

### State Management: Riverpod

All state lives in `lib/providers/`. The app uses `StateNotifierProvider`, `StreamProvider`, and `FutureProvider`. Providers are consumed in widgets via `ref.watch` / `ref.read`. There is no `ChangeNotifier` — do not introduce it.

### Navigation: GoRouter

Routes are defined in `lib/router/router.dart`. All route name constants are in `lib/router/routes_name.dart` — always use those constants when navigating, never raw strings. The router has a global `redirect` guard that checks `FirebaseAuth.instance.currentUser`; public routes are whitelisted in `_publicRoutes`. Navigate with `context.goNamed(RoutesName.xxx)` or `context.pushNamed(...)`.

**Known gap:** `RoutesName.goodsTransport`, `miniTruckDelivery`, `bikeParcel`, and `emergencyVehicle` are defined in `routes_name.dart` but have no corresponding `GoRoute` in `router.dart` — tapping those service buttons on the user dashboard hits the error page.

### Service Layer

`lib/services/` contains plain Dart classes that wrap Firebase calls. Services return `Result<T>` (a sealed class in `lib/core/errors/result.dart`) — never throw directly from a service. Use `runCatching { }` or `runCatchingSync { }` helpers from that file to wrap async/sync operations.

Error types are defined in `lib/core/errors/app_exceptions.dart`. `ErrorHandler` in the same directory maps Firebase exceptions to typed `AppException` subtypes.

### Firebase Collections

| Collection | Purpose |
|---|---|
| `users/{uid}` | User profile, role, verificationStatus, fcmToken |
| `vehicles/{vehicleId}` | Vehicle registration; subcollections: `documents/`, `schedules/`, `blocked_dates/`, `settings/` |
| `bookings/{bookingId}` | Full booking lifecycle; status enum values are camelCase (`pending`, `confirmed`, `inProgress`, `completed`, `cancelled`) |
| `drivers/{uid}` | Live location updates from `LiveLocationService` |
| `vehicleCatalog/{id}` | Read-only vehicle type catalog (world-readable) |
| `agreements/{uid_vehicleId}` | Signed driver agreements (immutable after creation) |
| `complaints/` / `feedbacks/` | Support center; created via Cloud Functions to get sequential ticket IDs |
| `banners/` / `offers/` / `offer_banners/` | Marketing content (read-only for clients) |

Firebase project: `zyppiride-2025`. Firestore rules enforce ownership at the collection level; Storage rules enforce ownership and 5 MB / `image/*` limits for vehicle images.

### Booking Status Flow

```
pending → confirmed → inProgress → completed
                ↘ cancelled (from any state by user/driver)
```

Status values in Firestore are camelCase strings (e.g., `'inProgress'`). Any query filtering on status must use camelCase. There is a known bug where the active booking query incorrectly uses `'in_progress'` — fix by using `'inProgress'`.

### Test Mode

`lib/core/constants/test_mode.dart` provides collection name switching via `--dart-define=E2E_TEST_MODE=true`. All Firestore collection references in services should use `TestMode.usersCollection`, `TestMode.bookingsCollection`, etc. — not hardcoded strings.

### Logging

Use `AppLogger` from `lib/core/utils/app_logger.dart` for all logging. It gates output on `kDebugMode`. Do not use `print()` directly.

## Key Patterns

**Result type:** All service methods return `Future<Result<T>>`. Unwrap with `.when(success: ..., failure: ...)` in providers or widgets.

**Fare calculation:** All fare logic lives in `lib/utils/fare_calculator.dart`. It applies night surcharge (10%, 22:00–06:00), peak hour surcharge (15%, weekday rush hours), waiting charges (free 3 min, ₹2/min after), GST 5%, and platform fee 5%.

**Driver verification gate:** Firestore rules enforce that a driver must have `verificationStatus == 'approved'` before they can set `isOnline = true` on any vehicle document. Client-side logic in `verification_provider.dart` and `driver_online_toggle.dart` mirrors this check.

## Firebase Security Rules

`firestore.rules` is deployed alongside the app. Key things to keep consistent:
- The `agreements` collection uses document IDs of the form `{uid}_{vehicleId}` — the `isOwner()` function uses `agreementId.matches(request.auth.uid + '_.*')`.
- The `drivers` collection currently has **no rules** — any writes will be denied in production. This must be added.
- `is_admin` field on user documents must not be user-writable. Rules need tightening on the `users` collection update path.

## Android Build Notes

- **Package name:** Currently `com.example.zyppi_ride` — must be changed to a production package name before Play Store submission.
- **Signing:** The release build type currently uses the debug keystore (`signingConfigs.getByName("debug")`). A production `key.properties` + keystore must be configured before any Play Store upload. The `key.properties` file must never be committed.
- **compileSdk / targetSdk:** 36 (Android 16).
- **minSdk:** Inherited from Flutter default (typically 21).
- Proguard/R8 is enabled for release via `proguard-rules.pro`. If adding new reflection-dependent libraries, add keep rules there.

## Known Active Issues (do not regress)

1. **Booking status string:** Active booking queries must use `'inProgress'` (camelCase), not `'in_progress'`.
2. **Ride history field:** History queries must order/filter by `createdAt`, not `bookingTime`.
3. **Missing routes:** Four service routes in `routes_name.dart` have no `GoRoute` entry — implementing them requires adding both the route and the corresponding screen.
4. **Splash asset:** `assets/animations/splash_animation.json` is commented out in `pubspec.yaml`. The splash screen falls back to an icon until this is restored.
