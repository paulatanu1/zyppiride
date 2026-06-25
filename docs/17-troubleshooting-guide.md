# 17 — Troubleshooting Guide

A reference list of failures observed in this codebase + recommended diagnosis paths. Severity follows the same scheme as [11](11-security-audit-report.md): Critical / High / Medium / Low.

## Rider-side issues

### "Could not connect" screen on launch [High]

**Where:** `_FirebaseErrorApp` in `lib/main.dart` shows when `Firebase.initializeApp()` throws.

**Likely causes:**
1. No network connectivity at first launch (cached config not yet available).
2. Corrupted / wrong `google-services.json` for the build flavour.
3. Missing SHA-1 fingerprint in Firebase Console — Google Sign-In fails to initialise.

**Resolution:**
- Pull-to-relaunch is enough for the first case. For the others, re-run `flutterfire configure --project=zyppiride-2025` and rebuild.

---

### OTP push never arrives [High]

**Where:** `onBookingCreated` Cloud Function pushes via FCM; relies on `users/{uid}.fcmToken`.

**Likely causes:**
1. Notification permission not granted.
2. `fcmToken` never written (sign-in did not call `NotificationService.saveFcmToken`).
3. Battery-saver mode on the device suppressing FCM.
4. Token went stale after backup-restore — needs `onTokenRefresh` write.

**Resolution:**
- Confirm `users/{uid}.fcmToken` is populated in Firestore.
- The **fallback always works**: OTP is also shown inside the app on `TrackBookingScreen`.

---

### "No vehicles available" on Reserve [Medium]

**Where:** `VehicleSearchService.searchVehicles` filters by `isOnline`, city, and type.

**Likely causes:**
1. No drivers in your city are currently online.
2. The user's auto-detected city differs from how drivers registered ("Mumbai" vs "मुंबई" vs "Bombay").
3. Missing composite index — failure throws `DatabaseException` rather than empty list.

**Resolution:**
- Toggle pickup city manually.
- Check Firebase Console → Firestore → Indexes for an error banner.
- Confirm a driver is actually online via the admin panel.

---

### "Page not found" on tile tap [Low]

**Where:** `router.dart` `errorBuilder`.

**Cause:** Tapping a dashboard tile whose route name isn't wired up. The historic gaps for `goodsTransport`, `miniTruckDelivery`, `bikeParcel`, `emergencyVehicle` have been closed — all four now have `GoRoute` entries. If a new gap appears, add the `GoRoute` to `router.dart` alongside the constant in `routes_name.dart`.

---

### Cancellation fee charged unexpectedly [Medium]

**Where:** `BookingService.cancelBooking` — `cancellationFee = baseFare * 0.20` when cancelling a `confirmed` booking.

**Note for support:** The fee applies only after the driver has accepted. A `pending` booking cancels free.

## Driver-side issues

### Online toggle is greyed out [High]

**Where:** `DriverOnlineToggle` widget + `firestore.rules` `vehicles` update.

**Diagnostic flow:**
```mermaid
flowchart TD
  Q[Toggle disabled?] --> V{users/{uid}.\nverificationStatus}
  V -- 'pending' or 'submitted' --> A1[Admin hasn't approved you yet]
  V -- 'rejected' --> A2[Re-upload documents — see notes]
  V -- 'approved' --> D{vehicles/{id}.\ndocumentStatus}
  D -- not 'approved' --> A3[Per-vehicle approval pending]
  D -- 'approved' --> AG{agreements/{uid_vehicleId}\nexists?}
  AG -- no --> A4[Sign agreement at\n/agreement-signing?vehicleId=]
  AG -- yes --> A5[Bug — file ticket]
```

---

### "Permission denied" when toggling online [High]

**Where:** Server-side check in `firestore.rules`: `(!isGoingOnline() || resource.data.documentStatus == 'approved')`.

**Cause:** Trying to flip `isOnline = true` on a vehicle whose `documentStatus` is not `'approved'`. The client UI should already block this; if you see it from a power user, it's because the in-memory eligibility state was stale.

**Resolution:** `verification_provider.dart`'s stream picks up changes within seconds — pull-to-refresh the dashboard and retry.

---

### Live location not updating on rider's map [Medium]

**Where:** `LiveLocationService.startTracking` → writes to `drivers/{driverId}`.

**Likely causes:**
1. Location permission denied (`Geolocator.checkPermission()` returns `denied`).
2. Device location services off.
3. `distanceFilter: 10 m` means the rider sees zero updates while the driver is stationary — this is by design.
4. Driver app backgrounded on iOS without `UIBackgroundModes` configured.

**Resolution:**
- App should prompt for permission on first start of a trip — accept "Always" if asked.
- For iOS background tracking, add `location` to `UIBackgroundModes` in `Info.plist`.

---

### Trip won't start — "Invalid OTP" [Medium]

**Where:** `BookingService.startTrip` compares the entered OTP to `booking.rideOtp`.

**Cause:** Driver mistyped, or the rider read the wrong booking's OTP (a rider with multiple historical bookings).

**Resolution:**
- Confirm the rider opened **the current active booking**, not a historical one.
- The OTP is 6 digits, numeric only.

## Build / deploy issues

### `flutter build appbundle` succeeds, Play Store rejects [High]

**Cause:** AAB is signed with the debug keystore (default in this repo — see S-01 in [11](11-security-audit-report.md)).

**Resolution:** Generate a production keystore and wire it through `key.properties`. See [12 — Deployment Guide](12-deployment-guide.md).

---

### `App Check token failed` in console [Medium]

**Cause:** Release build's package fingerprint doesn't match the Play Integrity registration in Firebase Console, or Play Integrity API is not enabled in Google Cloud.

**Resolution:**
- Enable Play Integrity API in GCP Console.
- Add the upload key SHA-1 / SHA-256 to Firebase Console → App Check → Play Integrity.

---

### `dart run build_runner build` fails with "conflicting outputs" [Low]

**Resolution:** `dart run build_runner build --delete-conflicting-outputs`.

---

### Firestore query fails with `FAILED_PRECONDITION: requires an index` [Medium]

**Cause:** A new query path was added without updating `firestore.indexes.json`.

**Resolution:**
- The error message contains a deep link to auto-create the index in Firebase Console — use it.
- After creation, **also** add the index to `firestore.indexes.json` so it deploys with CI; otherwise the next `firebase deploy --only firestore:indexes` could orphan it.

---

### Cloud Function deploy fails on `npm --prefix functions run lint`

**Cause:** ESLint errors in `functions/` source.

**Resolution:**
- Run `npm --prefix functions run lint -- --fix`.
- Do **not** add `--force` to the deploy.

## Firestore-rules failures

### `permission-denied` on user document update [Medium]

**Causes (by clause):**
- Client included `isAdmin` in the write → forbidden.
- Client tried to set `verificationStatus = 'approved'` → only admin can.
- Client tried to overwrite the doc with `set()` → use `update()` (the create rule rejects writes that include `isAdmin` or non-`pending` `verificationStatus`).

---

### `permission-denied` on booking create [Medium]

**Cause:** Missing required keys, `userId != auth.uid`, or `status != 'pending'`.

**Resolution:** Check `BookingService.createBooking` always sets `BookingStatus.pending`. If the rule changed required keys, update the keys list in `firestore.rules` `data.keys().hasAll([...])`.

---

### `permission-denied` reading a driver location [Low]

**Cause:** The reader is neither the driver, an admin, nor the rider on `drivers/{id}.currentBookingId`. Sometimes happens at trip start because `currentBookingId` writes a moment late.

**Resolution:** retry within ~1 s; `LiveLocationService.startTracking` sets it as the first write.

## Performance & cost

### Firestore reads spike

**Likely causes:**
1. `BookingService.getUserStats` loads **all** completed bookings to compute total spent / distance. With history growth, switch to a counter document maintained by a Cloud Function trigger.
2. Live `getActiveBookingStream` left subscribed after navigation. Use Riverpod's `autoDispose` family providers so the listener tears down on widget unmount.

### Storage egress spike

**Likely cause:** Uncached vehicle image loads. The codebase already uses `cached_network_image: ^3.3.1`; confirm the cache isn't being cleared on every cold start.

## Logs and diagnostics

- All in-app logs flow through `AppLogger` (debug builds only). Filter by `tag:` — useful tags: `AuthService`, `BookingService`, `NotificationService`, `LiveLocation`, `FCM`.
- Cloud Functions logs: `firebase functions:log --only onBookingCreated --limit 50`.
- Firestore audit: Firebase Console → Firestore → Usage tab for read/write hot spots.
