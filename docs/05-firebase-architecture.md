# 05 — Firebase Architecture

Firebase project: `zyppiride-2025` (configured in `.firebaserc`, `lib/screens/firebase_options.dart`).

## Enabled Firebase products

| Product | Flutter package | Where it's used |
|---|---|---|
| Firebase Core | `firebase_core: ^4.1.0` | `main.dart` initialisation |
| Authentication | `firebase_auth: ^6.0.2` | `services/auth_service.dart` — email, phone, Google |
| Cloud Firestore | `cloud_firestore: ^6.1.0` | every service in `lib/services/` |
| Cloud Storage | `firebase_storage: ^13.0.2` | `services/vehicle_service.dart` (vehicle images), profile photos |
| Cloud Messaging | `firebase_messaging: ^16.1.1` | `services/notification_service.dart` |
| Cloud Functions | `cloud_functions: ^6.0.4` | callables — `createComplaint`, `createFeedback` |
| App Check | `firebase_app_check: ^0.4.1+4` | `main.dart` — Play Integrity / App Attest |
| Analytics | `firebase_analytics: ^12.0.4` | `auth_service.dart` — `sign_up`, `login` events |
| Local notifications | `flutter_local_notifications: ^18.0.0` | Foreground display of FCM messages |

## Cloud Functions deployed

Source: `functions/` (Node.js, deployed via `firebase deploy --only functions`). Predeploy: `npm --prefix functions run lint`.

| File | Function | Type | Purpose |
|---|---|---|---|
| `index.js` | `onBookingCreated` | Firestore trigger (`onDocumentCreated('bookings/{bookingId}')`) | Reads new booking's `rideOtp` and pushes it to the rider via FCM as a high-priority notification. |
| `index.js` | `seedVehicleCatalog` | HTTPS (`onRequest`) — POST only, admin-only | One-shot endpoint that writes the canonical `vehicleCatalog/india2025` document. Verifies the caller's ID token then checks `users/{uid}.isAdmin == true`. |
| `feedback-suggestion-fun.js` | `createComplaint` | HTTPS callable (`onCall`) | Creates a support ticket. Generates `ticketId = ZY-YYYYMMDD-{rand 100..999}`. Falls back to `data.userId` if no auth context. |
| `feedback-suggestion-fun.js` | `createFeedback` | HTTPS callable (`onCall`) | Creates a rating + free-text feedback record. Generates `feedbackId = FB-YYYYMMDD-{rand 100..999}`. |

Additional files in `functions/` are admin utilities, **not** deployed as live functions:
- `adminkeyypdate.js`, `updateAllUsers.js`, `getFirestoreStructure.js` — operational scripts.
- `index-1.js`, `index-mailsend-prod.js` — alternative or staging versions, kept in repo but not exported.

> ⚠️ **Functions runtime gap**: `functions/feedback-suggestion-fun.js` uses the v1 SDK (`functions.https.onCall`) while `functions/index.js` uses the v2 SDK (`onDocumentCreated`, `onRequest`). Both are valid but mix-and-matching SDKs can cause confusion at deploy. Consider standardising on v2.

## Project structure (deployment surface)

```
firebase.json
├── firestore.rules        → Firestore security rules
├── firestore.indexes.json → composite indexes (~24)
├── storage.rules          → Cloud Storage security rules
└── functions/             → Cloud Functions codebase 'default'
```

`firebase.json` registers a single function codebase with predeploy lint. No hosting, no remote config, no extensions configured.

## App Check configuration

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
  appleProvider: kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
);
```

- **Debug builds** (debug + profile) use the debug provider. The debug provider's token must be registered in Firebase Console for each developer device.
- **Release builds** use Play Integrity (Android) and App Attest (iOS). Both require platform-specific setup in their respective consoles.
- Firestore, Storage, and Functions can each be set to **enforce** App Check from the Firebase Console; this app fetches and verifies a token at startup as a sanity check (debug-only `getToken(true)` call in `main.dart`).

## Analytics events emitted

From `lib/services/auth_service.dart`:

| Event | Method param | Fires on |
|---|---|---|
| `sign_up` | `email`, `phone`, `google` | Successful new-user creation |
| `login` | `email`, `phone`, `google` | Successful returning-user sign-in |

No custom events for bookings, fare events, or driver-state transitions exist yet — these are an opportunity for product analytics expansion.

## Persistence + caching

- **Firestore offline cache** capped at **100 MB** (`main.dart` — `Settings(persistenceEnabled: true, cacheSizeBytes: 100 * 1024 * 1024)`).
- **Source.cache fallback** in `VehicleService.fetchVehicleCatalog` — tries server first, then cache if the server is unreachable, then returns `DatabaseException.notFound`.
- **Connectivity** signal available via `connectivity_plus: ^7.0.0` (but not yet wired into a global no-network banner).
- **Cached network images** via `cached_network_image: ^3.3.1`.

## FCM topic taxonomy

Defined in `lib/services/notification_service.dart`:

| Topic | Subscribed by |
|---|---|
| `all_users` | both roles on login |
| `users` | rider role on login |
| `drivers` | driver role on login |
| `user_{userId}` | rider role on login |
| `driver_{userId}` | driver role on login |

Topic subscriptions are toggled on `subscribeAsUser` / `subscribeAsDriver` and the matching `unsubscribeAs*` on logout. Per-user FCM tokens are stored on `users/{uid}.fcmToken` (`NotificationService.saveFcmToken`) for direct-device targeting from Cloud Functions.

## Cloud Functions deployment commands

```bash
# Deploy everything
firebase deploy

# Deploy only Firestore rules + indexes
firebase deploy --only firestore:rules,firestore:indexes

# Deploy only Storage rules
firebase deploy --only storage

# Deploy only Cloud Functions
firebase deploy --only functions

# Deploy a specific function
firebase deploy --only functions:onBookingCreated
```

Pre-deploy hook: `npm --prefix functions run lint` (see `functions/.eslintrc.js`). Hook failure aborts the deploy.

## Firebase project IDs in code

| Where | Value |
|---|---|
| `.firebaserc` | `"default": "zyppiride-2025"` |
| `lib/screens/firebase_options.dart` | Generated by `flutterfire configure` — contains per-platform `apiKey`, `appId`, `messagingSenderId`, `projectId` |
| `CLAUDE.md` | Android app ID `1:1026775080853:android:60b4bc7aa3e46e6843a09c` |

> 🔐 **Note**: `firebase_options.dart` and `google-services.json` carry public API keys (web-style restrictions, not secrets). The real authorisation surface is the security rules + App Check. **Do not** commit any private key (`functions/serviceAccountKey.json`, `key.properties`) — these are gitignored and a prior incident (commit `01b0d30 fix: remove exposed Firebase Admin SDK service account key`) confirms tooling has been retroactively cleaned. See [11 — Security Audit](11-security-audit-report.md).
