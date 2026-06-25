# 03 — System Architecture

## High-level topology

```mermaid
flowchart TB
  subgraph MobileClient[Mobile client — Flutter binary]
    UI[Screens & Widgets]
    SM[Riverpod Providers]
    SL[Service Layer]
    UI --> SM --> SL
  end

  subgraph FirebaseCloud[Firebase — zyppiride-2025 project]
    AUTH[Firebase Auth]
    FS[(Cloud Firestore)]
    STG[(Cloud Storage)]
    FCM[Cloud Messaging]
    FN[Cloud Functions]
    APPCHK[App Check]
    AN[Analytics]
  end

  subgraph External[External services]
    GS[Google Sign-In]
    GPL[Google Places / Geocoding]
    GEO[GPS / OS location service]
  end

  subgraph WebAdmin[Web admin panel — separate codebase]
    AdminUI[Admin UI]
  end

  SL <-->|REST / WS| AUTH
  SL <-->|reads + writes| FS
  SL <--> STG
  SL <-->|register topics + token| FCM
  SL -->|callable| FN
  MobileClient -->|App Check token| APPCHK
  MobileClient --> AN

  UI --> GS
  UI --> GPL
  SL --> GEO

  AdminUI --> FS
  AdminUI --> STG
  AdminUI -->|seedVehicleCatalog\nHTTPS| FN

  FN -- onBookingCreated --> FCM
  FN -- createComplaint/Feedback --> FS
```

## Layered view of the mobile client

```mermaid
flowchart TB
  L1[Presentation\nlib/screens/ + lib/widgets/]
  L2[State\nlib/providers/]
  L3[Services\nlib/services/]
  L4[Domain models\nlib/models/]
  L5[Core utilities\nlib/core/ + lib/utils/]
  L6[Routing\nlib/router/]

  L1 --> L2
  L2 --> L3
  L3 --> L4
  L3 --> L5
  L1 --> L6
```

- **Presentation** — `ConsumerWidget`/`ConsumerStatefulWidget` only (no `StatefulWidget` + `setState` over async data). Reads providers via `ref.watch` and triggers actions via `ref.read(notifier).method()`.
- **State** — Riverpod `Provider`, `StreamProvider`, `FutureProvider`, `StateNotifierProvider`. No `ChangeNotifier`. Family providers parameterise by `userId` / `vehicleId`.
- **Services** — plain Dart classes wrapping Firebase. Return `Future<Result<T>>` instead of throwing.
- **Models** — immutable data classes with `fromMap`/`toMap` and defensive `_parseDouble`/`_parseInt`/`_parseDateTime` helpers (Firestore can return `int` where a `double` is expected).
- **Core / utils** — `Result<T>`, `AppException` hierarchy, `AppLogger` (gates output on `kDebugMode`), `TestMode`, `FareCalculator`, `PaginationCursor` helpers.
- **Routing** — `GoRouter` with global `redirect` guard; route name constants in `RoutesName`.

## Request / data-flow patterns

### Read flow (live booking)

```mermaid
sequenceDiagram
  participant W as Widget (TrackBookingScreen)
  participant P as activeBookingProvider (StreamProvider)
  participant S as BookingService
  participant FS as Firestore
  W->>P: ref.watch(activeBookingProvider(userId))
  P->>S: getActiveBookingStream(userId)
  S->>FS: bookings where userId == uid AND status in [pending..inProgress]\norder by createdAt desc limit 1
  FS-->>S: snapshot stream
  S-->>P: Stream<Booking?>
  P-->>W: AsyncValue<Booking?>
```

### Write flow (create booking)

```mermaid
sequenceDiagram
  participant W as Widget (BookingConfirmationSheet)
  participant N as bookingNotifier (StateNotifier)
  participant BS as BookingService
  participant FS as Firestore
  participant FN as Cloud Function (onBookingCreated)
  participant FCM as Firebase Cloud Messaging
  W->>N: createBooking(request)
  N->>BS: createBooking(CreateBookingRequest)
  BS->>FS: get vehicles/{id}, users/{driverId}
  BS->>BS: FareDetails.calculate(...)
  BS->>BS: rideOtp = random 6-digit
  BS->>FS: bookings/{id}.set({..., rideOtp, status: pending})
  FS-->>FN: onDocumentCreated trigger
  FN->>FS: read users/{userId}.fcmToken
  FN->>FCM: send notification (title, body, data: {type, bookingId, otp})
  FCM-->>W: push (foreground → flutter_local_notifications)
  BS-->>N: Booking
  N-->>W: state.copyWith(booking)
```

### Live location flow

```mermaid
sequenceDiagram
  participant D as Driver app
  participant GPS as Geolocator (OS)
  participant LS as LiveLocationService
  participant DRV as drivers/{driverId}
  participant U as User app (TrackBookingScreen)
  D->>LS: startTracking(bookingId, driverId)
  LS->>GPS: getCurrentPosition + getPositionStream(distanceFilter: 10m)
  loop on every position
    GPS-->>LS: Position
    LS->>DRV: update(latitude, longitude, heading, speed, lastUpdated, currentBookingId)
  end
  U->>DRV: snapshots()
  DRV-->>U: Stream<DriverLocationData>
  D->>LS: stopTracking() at trip end → clear currentBookingId
```

## Cross-cutting concerns

| Concern | Implementation |
|---|---|
| Error model | `lib/core/errors/app_exceptions.dart` (AuthException, DatabaseException, ValidationException, NetworkException, StorageException, UnknownException). `ErrorHandler.handle(e, st)` converts Firebase exceptions into typed `AppException`s. |
| Result type | `Result<T>` sealed class (Success / Failure) with `when`, `map`, `flatMap`, `getOrThrow`, `getOrElse`. Wrapped via `runCatching` / `runCatchingSync`. |
| Logging | `AppLogger` (info/warning/error/debug/success/firestore/userAction). Output suppressed in release builds via `kDebugMode`. |
| Offline cache | Firestore persistence enabled in `main.dart` with a 100 MB cache cap. |
| App attestation | Firebase App Check — Play Integrity (Android release), App Attest (iOS release), debug provider for debug/profile. |
| Background messaging | `firebaseMessagingBackgroundHandler` registered as a top-level `@pragma('vm:entry-point')` function in `notification_service.dart`. |
| Global snackbars | `scaffoldMessengerKey` exported from `main.dart` so snackbars survive route changes. |

## Module dependency graph (selected)

```mermaid
flowchart LR
  Router --> Screens
  Screens --> Providers
  Providers --> Services
  Services --> Models
  Services --> Core[core/errors + core/utils]
  Services --> Firebase[firebase_core + firebase_auth + cloud_firestore +\nfirebase_storage + firebase_messaging + cloud_functions]
  Providers --> Models
  Widgets --> Providers
  Screens --> Widgets
```

## Build artefacts

| Platform | Output | Build command |
|---|---|---|
| Android (Play Store) | `app/build/outputs/bundle/release/app-release.aab` | `flutter build appbundle --release` |
| Android (sideload / QA) | `app/build/outputs/flutter-apk/app-release.apk` | `flutter build apk --release` |
| iOS | Xcode-archived `.ipa` (release scheme) | `flutter build ipa --release` (requires Apple signing) |

The repository also has `web/`, `macos/`, `windows/`, `linux/` scaffolds carried by `flutter create`, but they are **not** the supported delivery targets — no platform-specific configuration has been added beyond the defaults.
