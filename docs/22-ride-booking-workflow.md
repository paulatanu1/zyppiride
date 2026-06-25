# 22 — Ride Booking Workflow

Authoritative end-to-end specification of the booking lifecycle as implemented. Cross-references: [06 — Firestore Schema](06-firestore-schema.md) for field shapes, [10 — API & Service Layer](10-api-and-service-layer.md) for method signatures.

## State machine

```mermaid
stateDiagram-v2
  [*] --> pending: BookingService.createBooking
  pending --> confirmed: driver accepts (acceptBooking)
  pending --> rejected: driver rejects (rejectBooking)
  pending --> cancelled: rider cancels (cancelBooking) - no fee
  pending --> expired: stale > N min (expireOldBookings; admin-only today)
  confirmed --> driverArriving: optional intermediate
  confirmed --> arrived: driverArrived
  driverArriving --> arrived: driverArrived
  arrived --> inProgress: startTrip(otp)
  inProgress --> completed: completeTrip
  confirmed --> cancelled: rider cancels - 20% base-fare fee after 2 min from confirm
  driverArriving --> cancelled: rider cancels
  completed --> [*]
  cancelled --> [*]
  rejected --> [*]
  expired --> [*]
  arrived --> [*]: cancellation also possible
```

Status values are stored as the enum's `.name` (camelCase: `pending`, `confirmed`, `driverArriving`, `arrived`, `inProgress`, `completed`, `cancelled`, `rejected`, `expired`).

## Phase 1 — Search

```mermaid
sequenceDiagram
  participant R as Rider
  participant App as App
  participant FS as Firestore
  R->>App: open /reserve-vehicle, set city + type
  App->>FS: vehicles where isOnline=true AND city=X AND vehicleDetails.type=Y (limit 20)
  Note over FS: composite index: isOnline + location.city + vehicleDetails.type
  FS-->>App: results
  App->>App: client-side filters (seats, AC) in VehicleSearchService._processVehicleDocs
  App-->>R: list of AvailableVehicle
```

Failure modes:
- Missing index → `DatabaseException` (not silently downgraded to a broader query — by design).
- No results → empty list (UI shows "No vehicles available").

## Phase 2 — Confirmation & creation

```mermaid
sequenceDiagram
  participant R as Rider
  participant App as App
  participant BS as BookingService
  participant FS as Firestore
  R->>App: pick vehicle → BookingConfirmationSheet
  App->>BS: createBooking(CreateBookingRequest)
  BS->>FS: get vehicles/{id}
  BS->>FS: get users/{driverId}
  alt promo code present
    BS->>FS: get offers where code == upper(promoCode) AND isActive == true (limit 1)
  end
  BS->>BS: FareDetails.calculate(...)
  BS->>BS: rideOtp = random 6-digit
  BS->>FS: bookings/{newId}.set({status: pending, rideOtp, fareDetails, vehicle, driver, ...})
  BS-->>App: Booking
  App-->>R: navigate to /track-booking
```

Required fields on create (enforced by `firestore.rules`): `userId, userPhone, userName, bookingType, status, pickupLocation, dropLocation, vehicle, driver, fareDetails, paymentMethod, paymentStatus, createdAt, updatedAt`. The client must set `status == 'pending'`.

## Phase 3 — Driver acceptance

```mermaid
sequenceDiagram
  participant Drv as Driver app
  participant DBS as DriverBookingDashboard
  participant BS as BookingService
  participant FS as Firestore
  loop continuous
    FS-->>DBS: getDriverPendingBookingsStream(driverId) — where driver.driverId == uid, status == 'pending'
  end
  Drv->>DBS: tap "Accept" on a request
  DBS->>BS: acceptBooking(bookingId, driverId)
  BS->>FS: verify booking ownership and status == 'pending'
  BS->>FS: bookings/{id}.update({status: 'confirmed', confirmedAt, updatedAt})
```

`acceptBooking` is a two-step server interaction (read + write) but is **not transactional**. Two drivers cannot be assigned to the same booking because the booking already carries `driver.driverId` at creation — a single specific driver is the *target* from creation onward, not a pool that drivers compete for. See [23 — Driver Assignment Workflow](23-driver-assignment-workflow.md).

## Phase 4 — En route → arrived → start

```mermaid
sequenceDiagram
  participant Drv as Driver app
  participant LS as LiveLocationService
  participant FS as Firestore (drivers/{id})
  participant R as Rider app (TrackBookingScreen)
  Drv->>LS: startTracking(bookingId, driverId)
  LS->>FS: drivers/{id}.set(currentBookingId, lastUpdated)
  LS->>FS: initial Position write (lat/lng/heading/speed)
  loop every position update (≥10m delta)
    LS->>FS: drivers/{id}.update(lat, lng, heading, speed, lastUpdated)
  end
  FS-->>R: getDriverLocationStream(driverId) emits each update
  Drv->>FS: bookings/{id}.update(status: 'arrived', updatedAt)
  R->>R: app shows "Driver arrived" + OTP visible
  Drv->>R (in person): asks for OTP
  R->>Drv (verbal): "534821"
  Drv->>FS: startTrip(bookingId, driverId, '534821')
  Note over Drv,FS: BookingService.startTrip verifies otp client-side, then update status: 'inProgress'
```

## Phase 5 — In-progress tracking

While the booking is `inProgress`:
- Driver app continues streaming location to `drivers/{driverId}` until `stopTracking()`.
- Rider app's `TrackBookingScreen` listens to the booking snapshot for status changes and to the driver location for the map marker.
- The rider can call/message the driver via `url_launcher` (tel:/sms:) — no in-app chat yet.

## Phase 6 — Completion

```mermaid
sequenceDiagram
  participant Drv as Driver
  participant BS as BookingService
  participant FS as Firestore
  participant R as Rider
  Drv->>BS: completeTrip(bookingId, driverId, {actualDistance, actualDuration, waitingMinutes, tollCharges})
  alt actuals differ from estimate
    BS->>FS: get vehicles/{vehicleId}
    BS->>BS: FareDetails.calculate(actuals)
  end
  BS->>FS: bookings/{id}.update(status: 'completed', completedAt, [fareDetails], updatedAt)
  Drv->>FS: recordPaymentReceived(amount)
  Note over Drv,FS: paymentStatus → 'completed' when remainingAmount == 0
  R->>FS: addUserRating(bookingId, userId, rating, review)
  BS->>FS: batch update driver.ratingSum, driver.ratingCount, driver.rating, driver.totalTrips on each of driver's vehicles
```

## Phase 7 — Cancellation (rider-initiated)

`BookingService.cancelBooking(bookingId, userId, {reason})`:

```dart
if (!booking.canCancel) return false;        // canCancel ⟺ status in [pending, confirmed]
final cancellationFee = booking.status == BookingStatus.confirmed
    ? booking.fareDetails.baseFare * 0.20    // 20% of base fare
    : null;
update({
  status: 'cancelled',
  cancellationReason: reason ?? 'Cancelled by user',
  cancelledBy: 'user',
  cancelledAt: now,
  cancellationFee,
  updatedAt: now,
});
```

`FareCalculator.calculateCancellationFee` provides a richer rule (free within 2 minutes of confirmation) but is **not** wired into `BookingService.cancelBooking` today — the current code charges 20 % for any rider cancellation after confirmation. This is an inconsistency to address.

## Phase 8 — Driver rejection

`BookingService.rejectBooking(bookingId, driverId, reason?)`:

- Allowed only when status is `pending`.
- Writes `status: 'rejected'`, `cancellationReason: reason ?? 'Driver rejected the booking'`, `cancelledBy: 'driver'`, `cancelledAt: now`.
- The rider's `getActiveBookingStream` will drop this booking from the active set (rejected is not in `[pending, confirmed, driverArriving, arrived, inProgress]`).

> The current implementation targets a single driver. There is no fallback that re-tries with a different driver — this is an opportunity for [23 — Driver Assignment Workflow](23-driver-assignment-workflow.md).

## Concurrency & integrity considerations

- **OTP generation:** uses `dart:math.Random()`, not `Random.secure()`. For high-value rides this should be tightened.
- **Fare snapshot:** taken at booking creation. Recalculation on completion only happens if actual distance/duration/waiting/toll differ.
- **No transactions** are used in this flow — every write is a single-doc update. This is safe because each booking has a single target driver and the rules' field whitelists prevent concurrent writers from stomping on each other's fields.
- **Per-driver active-booking invariant:** the codebase relies on the convention that a driver runs one ride at a time. There's no server constraint enforcing this — two simultaneous accepts on different bookings would both succeed.

## Failure-mode handling

| Failure | Behaviour |
|---|---|
| Push OTP fails | Rider still sees OTP in-app on `TrackBookingScreen` |
| Network drop mid-trip | Firestore offline cache buffers writes; reconnect flushes queue |
| Driver app killed | Live location stops; `LiveLocationService.stopTracking` cleanup only runs on graceful exit. The next time the driver opens the app and resumes the booking, tracking restarts. |
| Pending booking with no driver action | Stays `pending` indefinitely today; needs `expireOldBookings` Cloud Function ([F-08](18-future-enhancements.md)) |
| Invalid OTP attempt | Client counter on `DriverBookingDashboardScreen` locks the booking after 3 misses for 5 minutes |

## Audit trail

Every state change writes `updatedAt = Timestamp.now()` and the corresponding milestone timestamp (`confirmedAt`, `startedAt`, `completedAt`, `cancelledAt`). The booking document itself is never deleted (`firestore.rules` `allow delete: if false`), preserving a complete history.
