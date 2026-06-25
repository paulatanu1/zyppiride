# 20 — Rider App Flow Documentation

End-to-end view of the **rider / customer** experience. Post-login route resolves to `/user-dashboard` for any user whose `users/{uid}.role` is `User`, `user`, or null (legacy accounts) — see `UserModel.isUser`.

## Top-level rider navigation map

```mermaid
flowchart TB
  Splash[/splash/] --> Login[/login/]
  Login --> Phone[/phone-auth/]
  Login --> Forgot[/forgot-password/]
  Login --> Register[/registration/]
  Register --> EmailVerify[/email-verification/]
  Register --> RoleSel[/role-selection/]
  RoleSel --> Home[/user-dashboard/]
  Login --> Home

  Home --> Reserve[/reserve-vehicle/]
  Home --> Local[/local-transport/]
  Home --> OS[/outstation/]
  Home --> Goods[/book-goods-carrier/]
  Home --> Mini[/mini-truck-delivery/]
  Home --> Bike[/bike-parcel/]
  Home --> Emrg[/emergency/]
  Home --> Offers[/offers-rewards/]
  Home --> Drawer[Drawer]

  Drawer --> Saved[/saved-addresses/]
  Drawer --> History[/user-ride-history/]
  Drawer --> Profile[/user-profile/]
  Drawer --> Support[/support-center/]
  Drawer --> Notif[/notifications/]

  Reserve --> Detail[/vehicle-details?vehicleId=/]
  Detail --> Confirm[BookingConfirmationSheet]
  Confirm --> Track[/track-booking/]
  Track --> History
```

## Sign-up / sign-in flow

```mermaid
sequenceDiagram
  participant R as Rider
  participant App as Mobile app
  participant Auth as Firebase Auth
  participant FS as Firestore
  R->>App: Open
  App->>App: SplashScreen
  alt Already signed in
    App->>FS: read users/{uid}.role
    App-->>R: route to /user-dashboard
  else Not signed in
    App-->>R: /login
    alt Email
      R->>App: register/login
      App->>Auth: create/signInWithEmailAndPassword
      App->>FS: users/{uid} merge {lastLoginAt}
    else Google
      R->>App: tap Google button
      App->>Auth: signInWithCredential(GoogleAuthProvider)
      App->>FS: users/{uid} create-or-update with displayName, photoURL
    else Phone
      R->>App: enter phone
      App->>Auth: verifyPhoneNumber (60s timeout)
      Auth-->>App: codeSent(verificationId, resendToken)
      App-->>R: VerifyOtpScreen (pinput)
      R->>App: enter 6-digit OTP
      App->>Auth: signInWithCredential(PhoneAuthProvider)
    end
    App->>FS: users/{uid} merge if new
    alt New user
      App-->>R: RoleSelectionScreen → user picks "User"
      App->>FS: users/{uid}.role = 'User'
    end
    App-->>R: /user-dashboard
  end
```

## Dashboard composition

Source: `lib/screens/user/user_dashboard.dart` + `user_dashboard_provider.dart`.

| Element | Backing data |
|---|---|
| Location bar (top) | `LocationBar` widget; consumes `location_provider` (GPS + geocoding) |
| Banner slider | `BannerSlider` reading `banners` collection |
| Offer banners | `OfferBannerSlider` reading `offer_banners` |
| Quick-action service tiles | `QuickActionButton` × N (Reserve, Local, Outstation, Goods, etc.) |
| Active booking strip | Live snapshot of the rider's active booking (if any) |
| Side drawer | `ModernDrawer` with profile, saved addresses, history, support, sign out |
| FCM subscription | `notificationProvider.notifier.subscribeAsUser(uid)` on dashboard entry |

The dashboard handles a **double-back-to-exit** gesture via `_lastBackPressedAt`.

## Booking flow (rider's journey)

```mermaid
sequenceDiagram
  participant R as Rider
  participant App as Mobile app
  participant FS as Firestore
  participant FN as onBookingCreated
  participant FCM as Cloud Messaging
  participant Drv as Driver app
  R->>App: tap service tile → /reserve-vehicle
  App->>FS: query vehicles (city, type, isOnline=true, isAvailable=true)
  FS-->>App: list of AvailableVehicle
  R->>App: pick vehicle → /vehicle-details
  App-->>R: show details + fare estimate
  R->>App: tap "Book"
  App-->>R: BookingConfirmationSheet (fare breakdown, payment, notes)
  R->>App: confirm
  App->>FS: BookingService.createBooking → bookings/{id} (status: pending, rideOtp: 6-digit)
  FS-->>FN: onDocumentCreated trigger
  FN->>FS: read users/{uid}.fcmToken
  FN->>FCM: push OTP notification
  FCM-->>R: device shows OTP
  App-->>R: navigate to /track-booking (stream-backed)
  Drv->>FS: accept (status: confirmed)
  FS-->>App: stream update
  Drv->>FS: status: driverArriving → arrived
  Drv->>App (via R): asks for OTP at pickup
  R->>Drv: tells OTP
  Drv->>FS: startTrip(otp) → status: inProgress
  Drv->>FS: completeTrip → status: completed
  R->>FS: addUserRating(rating, review)
```

## Screen catalogue (rider-side)

| Screen | Route | Notes |
|---|---|---|
| Splash | `/splash` | `SplashScreen` |
| Auth hub | `/auth` | `AuthScreen` (variant landing) |
| Login | `/login` | `LoginScreen` — email + Google + phone CTA |
| Phone auth | `/phone-auth` | `PhoneAuthScreen` (calls `PhoneAuthNotifier`) |
| Register | `/registration` | `RegisterScreen` |
| Email verify | `/email-verification?userId=` | `EmailVerificationScreen` |
| Role select | `/role-selection?userId=` | `RoleSelectionScreen` |
| Forgot password | `/forgot-password` | `ForgotPasswordScreen` |
| User dashboard | `/user-dashboard` | `UserDashboard` |
| Reserve vehicle | `/reserve-vehicle` | `ReserveVehicleScreen` + `vehicle_search_provider` |
| Vehicle details | `/vehicle-details?vehicleId=` | `VehicleDetailsScreen` |
| Local transport | `/local-transport` | `LocalTransportScreen` |
| Outstation | `/outstation` | `OutstationScreen` |
| Book goods carrier | `/book-goods-carrier`, `/goods-transport`, `/mini-truck-delivery`, `/bike-parcel` | `BookGoodsCarrierScreen` (params change preset type & title) |
| Track booking | `/track-booking` | `TrackBookingScreen` — live status + driver location + OTP fallback |
| User ride history | `/user-ride-history` | `UserRideHistoryScreen` |
| Offers & rewards | `/offers-rewards` | `OffersRewardsScreen` |
| Promotions | `/promotions` | `PromotionsScreen` |
| Saved addresses | `/saved-addresses` | `SavedAddressesScreen` + `saved_address_provider` |
| User profile | `/user-profile` | `UserProfileScreen` |
| Notifications | `/notifications` | `NotificationsScreen` (reads `users/{uid}/notifications`) |
| Support center | `/support-center` | `SupportCenterScreen` (calls `createComplaint`, `createFeedback` Cloud Functions) |
| Emergency | `/emergency`, `/emergency-vehicle` | `EmergencyScreen` |

## Real-time state on the rider side

`TrackBookingScreen` subscribes to two streams simultaneously:

1. `BookingService.getBookingStream(bookingId)` — booking status + ETA + fare changes.
2. `LiveLocationService.getDriverLocationStream(driverId)` — driver lat/lng/heading/speed.

The OTP is always shown on this screen as a fallback to FCM delivery (`functions/index.js` notes: "the passenger can still read the OTP from the Track Booking screen in the app").

## Saved addresses

`SavedAddressesScreen` lists addresses from `users/{uid}/savedAddresses`. Add via the `AddAddressModal` (Google Places autocomplete + reverse-geocoded label). On the booking confirmation sheet, saved addresses appear as quick chips for pickup/drop.

## Support workflow

`SupportCenterScreen` exposes:
- **Raise complaint** — opens a form (subject, description, priority, optional image). On submit, calls the `createComplaint` callable Cloud Function which writes to `complaints/{id}` with a generated `ticketId = ZY-YYYYMMDD-NNN`.
- **Send feedback** — opens a rating + message form. On submit, calls `createFeedback`, returning a `feedbackId = FB-YYYYMMDD-NNN`.

Both endpoints require an authenticated context; the historic `data.userId` fallback is flagged as a security cleanup item (S-07 in [11](11-security-audit-report.md)).

## Notification permissions on the rider side

Permission prompt fires once during `NotificationService.initialize()` (post-first-frame in `MyApp`). If denied, OTP / status pushes won't arrive — but `TrackBookingScreen` always shows the OTP in-app and status changes are reflected via the live snapshot.

## Sign-out (rider)

`ModernDrawer` → Sign out calls `AuthService.signOut()`. Today this does **not** also call `removeFcmToken` or `unsubscribeAsUser` — those should be added (see [F-12](18-future-enhancements.md)).
