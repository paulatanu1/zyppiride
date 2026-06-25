# 10 — API & Service Layer

The "API" of this app is the **service layer** plus a handful of **Cloud Functions** — there is no custom REST backend. All eleven services live under `lib/services/` and return `Future<Result<T>>` rather than throwing.

## Service inventory

| Service file | Class | Backing collection / FCM / Storage |
|---|---|---|
| `auth_service.dart` | `AuthService`, `PhoneAuthNotifier` | Firebase Auth, `users/{uid}` |
| `booking_service.dart` | `BookingService` | `bookings/{id}`, reads `vehicles/{id}`, `users/{driverId}`, `offers` |
| `vehicle_service.dart` | `VehicleService` | `vehicles/{id}`, `metadata/vehicleSearchMeta`, Storage `vehicles/{uid}/vehicle/*` |
| `vehicle_search_service.dart` | `VehicleSearchService` | reads `vehicles` with composite-index queries |
| `document_verification_service.dart` | `DocumentVerificationService` | `users/{uid}.verificationStatus`, `vehicles/{id}.documentStatus` |
| `driver_status_service.dart` | `DriverStatusService` | `vehicles/{id}.isOnline`, `users/{uid}.isOnline` |
| `live_location_service.dart` | `LiveLocationService` | `drivers/{driverId}` (flat fields) |
| `location_service.dart` | `LocationService` | `geolocator` + `geocoding` + Google Places |
| `notification_service.dart` | `NotificationService` | FCM, local notifications, `users/{uid}.fcmToken` |
| `offer_banner_service.dart` | `OfferBannerService` | `banners`, `offers`, `offer_banners` |
| `saved_address_service.dart` | `SavedAddressService` | `users/{uid}/savedAddresses/{id}` |

## Common contract

```dart
abstract class _ServiceContract {
  // Reads
  Future<Result<T>>   getX(...)        // one-shot read
  Stream<T>           watchX(...)      // long-lived subscription (may return plain values)

  // Writes
  Future<Result<T>>   createX(...)
  Future<Result<void>> updateX(...)
  Future<Result<void>> deleteX(...)
}
```

- **Returns** `Result<T>` — never throws. Wrap Firebase calls inside `try/catch`, then call `ErrorHandler.handle(e, stack)` to map to a typed `AppException`.
- **Reads** that are long-lived (e.g. active booking) return a `Stream<T>` directly (typically via `snapshots().map(...)`). The widget consumes them via a `StreamProvider`.
- **Test mode** — collections use `TestMode.usersCollection`, `TestMode.bookingsCollection`, etc., so a single `--dart-define=E2E_TEST_MODE=true` switch redirects to `e2e_test_*` collections.
- **Logging** — every service logs via `AppLogger` with a `tag:` set to its class name.

## `AuthService` (selected methods)

| Method | Returns | Notes |
|---|---|---|
| `signInWithEmail({email, password})` | `Future<AuthResult>` | Updates `users/{uid}.lastLoginAt`. Logs analytics. |
| `registerWithEmail({email, password, mobile})` | `Future<AuthResult>` | Pre-flight duplicate-mobile query; creates `users/{uid}` with `verificationStatus: 'pending'`. |
| `signInWithGoogle()` | `Future<AuthResult>` | `_createOrUpdateUserDocument` with displayName/photoURL. |
| `verifyPhoneNumber({phoneNumber, onCodeSent, onVerificationCompleted, onVerificationFailed, resendToken})` | `Future<void>` | 60 s timeout. |
| `signInWithPhoneCredential(credential)` | `Future<AuthResult>` | First-time creates user doc. |
| `sendPasswordResetEmail(email)` | `Future<({bool success, String? errorMessage})>` | Returns a record. |
| `sendEmailVerification()` / `checkEmailVerified()` | varies | Uses `auth.currentUser.reload()`. |
| `signOut()` | `Future<void>` | Google + Firebase sign-out in sequence. |
| `getUserRole(uid)` / `checkUserHasRole(uid)` | `Future<String?>` / `Future<bool>` | Drives post-login routing. |

All `_get*ErrorMessage(FirebaseAuthException)` helpers map Firebase error codes to user-friendly strings (e.g. `invalid-credential → "Invalid email or password..."`).

## `BookingService` API surface

### Reads
- `getBooking(id)`, `getBookingStream(id)`
- `getActiveBooking(userId)`, `getActiveBookingStream(userId)` — `where('status', whereIn: [pending, confirmed, driverArriving, arrived, inProgress])`, ordered by `createdAt` desc, `limit(1)`.
- `getUserBookings(userId, {limit, lastDocument, statusFilter, typeFilter})` — paginated.
- `getUserBookingsPaginated(...)` — returns `PaginatedResult<Booking>` with `lastDocument` cursor.
- `getUserBookingsStream(userId)` — live history.
- `getDriverPendingBookings(driverId)` / `getDriverPendingBookingsStream(driverId)`
- `getDriverActiveBooking(driverId)`
- `getDriverBookings(driverId, {limit, lastDocument})`
- `getUserStats(userId)` / `getDriverStats(driverId)` — uses Firestore aggregate `.count()`.

### Writes
| Method | Status transition |
|---|---|
| `createBooking(CreateBookingRequest)` | — → `pending` (sets `rideOtp`) |
| `updateStatus(bookingId, newStatus, ...)` | generic — also fills timestamp fields |
| `acceptBooking(bookingId, driverId)` | `pending → confirmed` (verifies driver) |
| `rejectBooking(bookingId, driverId, {reason})` | `pending → rejected` |
| `driverArrived(bookingId, driverId)` | `confirmed → arrived` |
| `startTrip(bookingId, driverId, otp)` | `arrived → inProgress` after OTP match |
| `completeTrip(bookingId, driverId, {actualDistance, actualDuration, waitingMinutes, tollCharges})` | `inProgress → completed`; re-runs `FareDetails.calculate` if actuals differ |
| `cancelBooking(bookingId, userId, {reason})` | `pending|confirmed → cancelled`; calculates 20 %-of-base-fare fee on cancelling a confirmed booking |
| `updatePaymentStatus(bookingId, status, {transactionId})` | sets `paymentStatus` |
| `recordPaymentReceived({bookingId, driverId, amountReceived})` | cash settlement; sets `paymentStatus = completed` when remaining hits zero. Returns `Result<void>`. |
| `addUserRating(bookingId, userId, rating, {review})` | also updates driver's rolling average via `_updateDriverRating` batch write |
| `addDriverRating(bookingId, driverId, rating, {review})` | rider rating from the driver's side |
| `expireOldBookings({minutesOld, adminOverride: true})` | **No-op without `adminOverride: true`** — should be called from a Cloud Function, not a client session. |

### OTP & fare
- 6-digit OTP generated via `(100000 + Random().nextInt(900000)).toString()` and embedded in the booking document.
- Promo discount fetched on creation via `_getPromoDiscount(promoCode)` against `offers` collection (matches `code` uppercase + `isActive == true`).

## `VehicleService`

| Method | Notes |
|---|---|
| `fetchVehicleCatalog({useCache})` | Server-first, cache fallback. Returns `Result<Map<String, dynamic>>`. |
| `uploadVehicleImages({images, userId, onProgress})` | Streams progress per image. Stores at `vehicles/{userId}/vehicle/{ts}.jpg`. |
| `registerVehicle({userId, locationData, vehicleDetails, vehicleImageUrls})` | Creates the vehicle doc; calls `_updateSearchMeta` to add city/type to `metadata/vehicleSearchMeta`. |
| `updateUserLicenseDetails({userId, licenseNumber, licenseValidUpto})` | Writes to `users/{uid}` (driving license fields). |
| `isRegistrationNumberExists(registrationNumber)` | Single-doc-limit query — uppercased. |

## `VehicleSearchService.searchVehicles({filters, limit})`

Server-side filters (each backed by a composite index): `isOnline`, `isAvailable`, `location.city`, `vehicleDetails.type`. Client-side filters (post-fetch, in `_processVehicleDocs`) cover anything not easily indexed — e.g. seat-count ranges. Failures are **not** silently downgraded to a broader query — missing indexes surface as a `DatabaseException`.

## `LiveLocationService`

- `checkLocationPermission()` — gates on `Geolocator.isLocationServiceEnabled` + permission status.
- `startTracking({bookingId, driverId})` — writes initial position, opens an adaptive `getPositionStream` with `distanceFilter: 10 m`, writes `{latitude, longitude, heading, speed (km/h), lastUpdated, currentBookingId}` on every event.
- `stopTracking()` — cancels subscription, deletes `currentBookingId` from the driver doc.
- `getDriverLocationStream(driverId)` — rider-side consumer.

## `NotificationService`

See [08 — Push Notifications](08-push-notifications.md).

## `LocationService`

Wraps `geolocator: ^14.0.2` (GPS) and `geocoding: ^4.0.0` (reverse geocoding) plus `google_places_flutter: ^2.1.1` for address autocomplete. Used by `LocationBar`, saved-address UI, and pickup/drop pickers.

## `DriverStatusService.toggleOnlineStatus({userId, isOnline})`

Batch-writes `isOnline` to all the driver's vehicles plus the user doc in a single transaction. Returns `DatabaseException.notFound('No vehicles registered')` if the driver has no vehicles. The matching Firestore rule prevents the server-side write from succeeding unless each vehicle's `documentStatus == 'approved'`.

## `SavedAddressService`

CRUD on `users/{uid}/savedAddresses/{id}`. Indexed as a collection-group query (`savedAddresses` collection-group index on `userId + createdAt`). Address model in `lib/models/saved_address_model.dart`.

## Cloud Functions called from the client

| Function | Called via | Where |
|---|---|---|
| `createComplaint` (callable) | `FirebaseFunctions.instance.httpsCallable('createComplaint')` | `SupportCenterScreen` (complaint submission) |
| `createFeedback` (callable) | `FirebaseFunctions.instance.httpsCallable('createFeedback')` | `SupportCenterScreen` (feedback submission) |
| `onBookingCreated` | not called directly — triggers automatically on `bookings/{id}` doc creation | — |
| `seedVehicleCatalog` | invoked from the admin panel only | — |

## Error model

`AppException` hierarchy (in `lib/core/errors/app_exceptions.dart`):

```
AppException (abstract)
├── AuthException
├── DatabaseException
│   └── DatabaseException.notFound(entity)
├── ValidationException
├── NetworkException
├── StorageException
└── UnknownException
```

`ErrorHandler.handle(error, stackTrace)` maps Firebase exceptions (`FirebaseAuthException`, `FirebaseException` from Firestore/Storage) to the appropriate subtype. Always pass the *original* `stackTrace` so `AppLogger.logException` can include it in the structured log.

## Calling services from a notifier — canonical example

```dart
class BookingNotifier extends StateNotifier<BookingState> {
  final BookingService _service;
  BookingNotifier(this._service) : super(const BookingState());

  Future<void> createBooking(CreateBookingRequest req) async {
    state = state.copyWith(isLoading: true, error: null);
    final booking = await _service.createBooking(req);
    state = state.copyWith(
      isLoading: false,
      booking: booking,
      error: booking == null ? 'Failed to create booking' : null,
    );
  }
}
```

(Some services return raw nullable values rather than `Result<T>` — `BookingService.createBooking` is one of them. Newer methods like `BookingService.recordPaymentReceived` use `Result<void>`. When refactoring, prefer `Result<T>` for new code.)
