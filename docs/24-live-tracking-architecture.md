# 24 — Live Tracking Architecture

## Overview

Driver-location tracking is the rider's lifeline once a booking is `confirmed` — they need to see the driver approaching and have ETA visibility. The implementation lives in `lib/services/live_location_service.dart` and `lib/providers/live_location_provider.dart`, backed by the `drivers/{driverId}` Firestore collection.

Design goals stated in the code:
- Canonical store: `drivers/{driverId}` with **flat fields** that match Firestore security rules exactly.
- One adaptive stream (`Geolocator.getPositionStream`) — no manual polling.
- Stationary periods cost nothing (covered by `distanceFilter`).
- Stop-and-clean on trip completion.

## End-to-end flow

```mermaid
sequenceDiagram
  participant Drv as Driver app
  participant Geo as OS Location
  participant LS as LiveLocationService
  participant FS as Firestore: drivers/{driverId}
  participant R as Rider app (TrackBookingScreen)
  Drv->>LS: startTracking(bookingId, driverId)
  LS->>LS: checkLocationPermission()
  LS->>FS: drivers/{driverId}.set({currentBookingId, lastUpdated}, merge: true)
  LS->>Geo: getCurrentPosition(LocationAccuracy.high, distanceFilter: 10m)
  Geo-->>LS: initial Position
  LS->>FS: drivers/{driverId}.update({latitude, longitude, heading, speed × 3.6, lastUpdated, currentBookingId})
  LS->>Geo: getPositionStream(LocationAccuracy.high, distanceFilter: 10m)
  loop on every Position event
    Geo-->>LS: Position (≥10m delta)
    LS->>FS: drivers/{driverId}.update(same set of fields)
  end
  loop continuous
    FS-->>R: snapshots() emits each write
    R->>R: update marker on map; recompute ETA
  end
  Drv->>LS: stopTracking() at trip end
  LS->>FS: drivers/{driverId}.update({currentBookingId: FieldValue.delete(), lastUpdated})
  LS->>Geo: subscription.cancel()
```

## Document shape

`drivers/{driverId}` (flat fields — matches `firestore.rules` `update` whitelist exactly):

| Field | Type | Source / Units |
|---|---|---|
| `latitude` | double | `Position.latitude` |
| `longitude` | double | `Position.longitude` |
| `heading` | double | `Position.heading` — degrees from true north |
| `speed` | double | `Position.speed × 3.6` — converted from m/s to km/h |
| `lastUpdated` | Timestamp | `FieldValue.serverTimestamp()` |
| `currentBookingId` | string? | set on `startTracking`, deleted on `stopTracking` |
| `isOnline` | bool? | maintained separately by `DriverStatusService` |

## Permission handling

`LiveLocationService.checkLocationPermission()`:

```dart
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) return false;

LocationPermission permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
  permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) return false;
}
if (permission == LocationPermission.deniedForever) return false;
return true;
```

`deniedForever` → user must enable location in OS settings. The UI should show a CTA that opens app settings via `url_launcher`.

## Why `distanceFilter: 10` (and why a single stream)

The codebase deliberately uses one adaptive `getPositionStream` rather than dual high-frequency/low-frequency streams. Trade-offs:

- **Battery friendly when stationary** — at a traffic light, no events fire, no writes occur.
- **Predictable Firestore cost** — at most one write per ~10 meters moved.
- **At 50 km/h** ≈ 14 m/s ≈ ~1.4 writes/second per driver. A 30-minute trip ≈ 2,500 writes per driver per trip in worst case (open highway). City driving is much less due to traffic lights / congestion.
- **At ≤ 0.5 km/h (walking pace)** → likely no writes at all due to GPS jitter staying under 10 m.

For very-high-precision tracking (HOV-lane verification etc.), the filter could be reduced to 5 m at the cost of doubling write volume.

## Authorization model for reading driver location

`firestore.rules` for `drivers/{driverId}` reads is unusually rich for a Firestore-only architecture:

```
allow read: if request.auth != null && (
  request.auth.uid == driverId ||
  isAdmin() ||
  (resource.data.currentBookingId != null &&
   exists(/databases/$(database)/documents/bookings/$(resource.data.currentBookingId)) &&
   get(/databases/$(database)/documents/bookings/$(resource.data.currentBookingId)).data.userId == request.auth.uid)
);
```

In English: a `drivers/{id}` document is readable only by:
1. The driver themselves.
2. An admin (`isAdmin == true`).
3. The rider on the booking referenced by `currentBookingId`.

This prevents arbitrary stalking — without an active booking, no other user can read the driver's GPS.

> ⚠ Each read costs **two extra Firestore document reads** behind the scenes (one for the booking, one for the rule helper). At scale, this contributes to read-quota burn. See [27 — Firebase Cost Optimization](27-firebase-cost-optimization.md) for mitigation.

## Rider-side consumption

`LiveLocationService.getDriverLocationStream(driverId)` returns `Stream<DriverLocationData?>` mapping the Firestore snapshot through `DriverLocationData.fromFirestore`. Consumed inside `TrackBookingScreen` via a `StreamProvider` (or directly subscribed in a `ConsumerStatefulWidget`).

The rider also independently subscribes to the booking document — so they see both:
- Status transitions (`confirmed → arrived → inProgress → completed`).
- Live driver position on the map.

## ETA computation

Currently the codebase stores `estimatedArrival` as a pre-formatted **string** at booking creation (`BookingService._calculateEta(estimatedDuration)` returns `"15 mins"` or `"1 hr 30 mins"`). It is **not** dynamically updated as the driver moves.

To get a live ETA, the rider client could:
1. Compute haversine distance from `drivers/{driverId}` to `bookings/{id}.pickupLocation` (or drop after pickup).
2. Use `drivers/{driverId}.speed` as a rough velocity estimate.
3. Periodically re-compute.

For accuracy in city traffic, call out to a routing API (Google Routes, OSRM) — at a cost per request. Cache aggressively client-side.

## What this codebase does NOT (yet) do

| Missing capability | Impact |
|---|---|
| **Background location** for driver after the app is killed/backgrounded | iOS will pause GPS within seconds of backgrounding. Android can keep going with a foreground service notification. Today, the driver must leave the app open. |
| **Geofencing for arrival auto-detection** | Driver manually taps "Arrived". Geofence around `pickupLocation` could automate this. |
| **Route polyline / Google Maps widget** | Rider sees driver position as a marker but no street-level route preview. The repo does not include `google_maps_flutter`. |
| **Driver path history** | Each Firestore write overwrites the previous; the historical breadcrumbs are lost. For dispute resolution, archive to a `tripTraces` collection or Cloud Storage. |
| **Anti-tampering** | A jailbroken driver could feed mock locations via Geolocator's mock-location API. Add `Position.isMocked` check before writing. |

## Cleanup on edge cases

- **App killed mid-trip:** `stopTracking()` does not run, so `currentBookingId` stays set on the driver doc. Subsequent reads by other riders are still blocked (their `userId` doesn't match the booking). When the driver re-opens the app and resumes the trip, `startTracking()` overwrites `currentBookingId` with the same value (no-op).
- **App killed and trip never resumed:** `currentBookingId` stays stale until the next trip's `startTracking()`. Consider a Cloud Function that on `bookings.status → completed` clears the matching `drivers/{driverId}.currentBookingId`.

## Failure tolerance

| Failure | Behaviour |
|---|---|
| GPS signal lost | Stream stays open; no events fire. Rider sees a stale position with old `lastUpdated`. UI should display "Last seen X seconds ago" to be transparent. |
| Network drop | Firestore offline cache buffers writes; flushes on reconnect. Rider's stream stops emitting until reconnected. |
| Permission revoked mid-trip | `Geolocator` throws on the stream; `LiveLocationService` logs and the subscription dies silently. Recommend showing a banner to the driver to re-grant permission. |
| Driver toggles off `isOnline` mid-trip | No automatic stop of tracking — the in-flight trip continues. Recommend forbidding the toggle when an active booking exists. |
