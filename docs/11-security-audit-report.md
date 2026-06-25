# 11 — Security Audit Report

This audit is derived from the actual contents of `firestore.rules`, `storage.rules`, `lib/main.dart`, `lib/services/`, `android/`, `pubspec.yaml`, and `functions/`. Severity tags use Critical / High / Medium / Low / Info.

## Executive summary

The Firestore security-rules implementation is **mature and defence-in-depth**. The biggest residual risks are at the build / deployment boundary (release signing using the debug keystore) and around payment integration (no live gateway, only manual cash). The historical service-account exposure has been remediated (commit `01b0d30`).

## Findings

### S-01 [High] Release builds are signed with the debug keystore
**Where:** `android/app/build.gradle.kts` — `signingConfigs.getByName("debug")` referenced from the `release` build type (per `CLAUDE.md` and `01b0d30..0f38d58` git log).

**Impact:** Any AAB / APK signed with the debug keystore cannot be uploaded to Play Store (rejected) and even if sideloaded, has no upgrade story (the upload key cannot be rotated). Anyone with the debug keystore can sign updates indistinguishable from the official build.

**Fix:** Generate a production `upload-keystore.jks`, populate `android/key.properties` (gitignored), and switch the `release` block to consume `signingConfigs.getByName("release")`. See [12 — Deployment Guide](12-deployment-guide.md).

---

### S-02 [Resolved] Firebase Admin SDK service-account key committed to git
**Status:** Remediated in commit `01b0d30 fix: remove exposed Firebase Admin SDK service account key`.

**Residual action:** The key must be **rotated** in Google Cloud IAM regardless of removal from the working tree — git history retains it. Confirm rotation in the Firebase Console → Project settings → Service accounts → Generate new private key, then revoke the old one.

---

### S-03 [Medium] Phone-auth resend not rate-limited client-side
**Where:** `PhoneAuthNotifier.sendOtp` — relies entirely on Firebase's `too-many-requests` error.

**Impact:** A determined attacker can drive up the SMS bill. Firebase has a per-project quota but the per-user/per-phone counter resets quickly.

**Fix:** Add a client-side cooldown (e.g. disable the "Resend" button for 30 s) and consider App Check enforcement on phone-auth (Firebase Console → Authentication → Settings → App Check).

---

### S-04 [Medium] No `users/{uid}` whitelist on update fields
**Where:** `firestore.rules` `match /users/{userId}` update block.

The rule blocks `isAdmin` escalation and constrains `verificationStatus` transitions, but **otherwise lets the owner write any field**. This means a malicious user could overwrite `verificationApprovedAt`, `verificationNotes`, `drivingLicenseValidUpto`, or `fcmToken` arbitrarily.

**Fix:** Add an `affectedKeys().hasOnly([...])` whitelist of fields the client may touch (e.g. `fullName`, `profileImageUrl`, `mobile`, `email`, `fcmToken`, `fcmTokenUpdatedAt`, `lastLoginAt`, `role`, `verificationStatus`, `verificationSubmittedAt`).

---

### S-05 [Medium] `metadata/vehicleSearchMeta` allows arbitrary writes
**Where:** `firestore.rules` `match /metadata/{document}` update.

Any authenticated user can append arbitrary strings to `cities` and `vehicleTypes`. This is a soft data-quality risk (search dropdown pollution), not a confidentiality risk.

**Fix:** Trigger search-meta updates only via a Cloud Function (Firestore-triggered on `vehicles/{id}` create), and tighten rules to admin-only writes.

---

### S-06 [Medium] No server-side OTP attempt rate-limit
**Where:** `BookingService.startTrip` — OTP comparison is a single Firestore round-trip.

**Impact:** With a 6-digit OTP and no lockout, brute-force is theoretically feasible from a malicious driver client (one in a million per attempt, but no upper bound on attempts).

**Fix:** Move OTP verification to a Cloud Function that increments a counter on each failure and locks the booking after N attempts. The function can also write `paymentStatus`-style audit data.

---

### S-07 [Medium] No CAPTCHA / App Check enforcement on Cloud Functions
**Where:** `functions/feedback-suggestion-fun.js` `createComplaint`, `createFeedback`.

The callables accept an unauthenticated `data.userId` fallback ("Falls back to data.userId if no auth context"), which means anyone can flood Firestore with tickets using a known UID.

**Fix:** Remove the `data.userId` fallback, require `context.auth`, and (optionally) configure App Check enforcement for these functions.

---

### S-08 [Low] `verifyPhoneNumber` deprecation in Firebase Auth 6
**Where:** `AuthService.verifyPhoneNumber`.

`firebase_auth: ^6.0.2` deprecates `verifyPhoneNumber` in favour of the new sign-in-with-phone flow. Existing usage continues to work but should migrate before a major-version bump.

---

### S-09 [Low] Foreground push-payload encoding loses data types
**Where:** `NotificationService._encodePayload` — joins `key=value` pairs.

If a payload value contains `&`, parsing breaks. Today, only short strings (`bookingId`, `otp`, `type`) are passed, so it's safe. If payloads grow, switch to JSON.

---

### S-10 [Low] No CSP / clickjacking protections on web target
**Where:** `web/index.html`.

The web build is not a supported target, but the boilerplate `web/` is committed. If web is ever enabled, configure Firebase Hosting with strict CSP and `X-Frame-Options`.

---

### S-11 [Info] Firestore offline cache is 100 MB
**Where:** `lib/main.dart` `Settings(cacheSizeBytes: 100 * 1024 * 1024)`.

Persisted cache contains potentially sensitive trip data (pickup/drop addresses, OTP, fare). On a shared device or after device sale, this data is recoverable until cleared. Consider:

- Lower the cap (e.g. 25 MB).
- Call `FirebaseFirestore.instance.terminate()` + `clearPersistence()` on explicit sign-out.

---

### S-12 [Info] Logging of partial FCM tokens to console
**Where:** `notification_service.dart` — `AppLogger.debug('Token: ${token.substring(0, 20)}...', tag: 'FCM')`.

Truncated tokens are fine. The wrapping `AppLogger` already gates on `kDebugMode`, so release builds emit nothing.

---

### S-13 [Info] Storage rules cap image uploads at 5 MB
**Where:** `storage.rules` `match /vehicles/{userId}/{allPaths=**}` — `request.resource.size < 5 * 1024 * 1024`, `contentType.matches('image/.*')`.

Good. **Note**: the `users/{uid}/{allPaths=**}` and `support/{uid}/{allPaths=**}` paths do **not** have size or content-type caps. A malicious authenticated user could upload large arbitrary files (within Firebase's billing limits) to either path. Recommend mirroring the 5 MB / `image/*` cap.

---

### S-14 [Info] Versioned dependency hygiene
`pubspec.yaml` uses caret constraints (`^1.2.3`) throughout. Run `flutter pub outdated --mode=null-safety` quarterly; high-risk packages to watch are `firebase_*` (security fixes), `geolocator` (background-location API changes per OS release), and `signature` (we already note a 6.x upgrade in `pubspec.yaml`).

## Defence-in-depth wins (worth keeping)

- **`isAdmin` self-escalation is blocked on both create and update.** Cannot be set via mobile client at all.
- **`verificationStatus` state machine** on the client write is server-enforced.
- **Driver online-toggle gate** reads existing `documentStatus` rather than the incoming write — prevents a single-doc poisoning attack.
- **Driver-location reads** are scoped to the driver themselves, an admin, or the rider on the active booking — prevents arbitrary GPS stalking.
- **Booking field-level write whitelists per actor.** Riders cannot change fare; drivers cannot change participants; once `status == 'completed'`, only the receipt fields are mutable.
- **No client deletes on bookings.** Cancellation is a status transition, preserving the audit trail.
- **Agreement immutability** (`allow update, delete: if false`) for compliance.
- **App Check** initialised in `main.dart` for all platforms; ready to enforce.

## Recommended next actions

1. **Rotate the Admin SDK service-account key** in Google Cloud IAM (must be done outside the repo).
2. **Generate a production Android keystore** and wire it via `key.properties`.
3. **Tighten `users` update rule** with a key whitelist (S-04).
4. **Remove the `data.userId` fallback** in `createComplaint` and `createFeedback` (S-07).
5. **Add a client-side OTP-resend cooldown** (S-03).
6. **Move OTP verification to a Cloud Function** with attempt counting (S-06).
7. **Enable App Check enforcement** in Firebase Console (Firestore, Storage, Functions) once a release build with Play Integrity is shipped.
8. **Add size / content-type rules** to `storage.rules` for `users/` and `support/` paths (S-13).
