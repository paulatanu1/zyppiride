# 15 — User Manual

This manual covers the **rider / customer** experience. For drivers, see the role-specific sections in [16 — Admin Manual](16-admin-manual.md) (drivers are operated similarly to admins — they manage their own fleet onboarding).

## Getting started

### Install
1. Download **Zyppi Ride** from the Play Store / App Store (when released).
2. Open the app — you'll see the splash screen, then the login screen.

### Create an account

You can sign up three ways:

| Method | Steps |
|---|---|
| **Email + password** | Tap "Sign Up" → enter mobile, email, password → verify email (link sent by Firebase) → select role "User" |
| **Google** | Tap "Continue with Google" → choose your account → select role "User" |
| **Phone** | Tap "Continue with Phone" → enter your mobile (with country code) → enter the 6-digit OTP from SMS → select role "User" |

Phone OTP autofills on Android via SMS (`sms_autofill` package). On iOS, paste the code from Messages.

### Reset password

From the login screen → "Forgot Password" → enter your email → Firebase sends a reset link.

## Home (rider dashboard)

The user dashboard (`UserDashboard`) shows:

- **Top bar** — your current pickup location (auto-detected or chosen).
- **Banner slider** — current promotions and announcements.
- **Service tiles** — Reserve a Vehicle, Local Transport, Outstation, Book Goods Carrier, Mini Truck, Bike Parcel, Emergency, Offers & Rewards.
- **Side drawer** (☰ icon) — Saved Addresses, Ride History, Support Center, Profile, Sign Out.

## Booking a ride

```mermaid
flowchart LR
  A[Open dashboard] --> B[Tap "Reserve a Vehicle"]
  B --> C[Enter pickup & drop]
  C --> D[Select vehicle from list]
  D --> E[Confirm fare & payment method]
  E --> F[Booking placed — waiting for driver]
  F --> G[Driver accepts]
  G --> H[Driver arrives → share OTP]
  H --> I[Trip in progress — live tracking]
  I --> J[Trip ends → pay → rate]
```

### Step-by-step

1. **Pick service** — from the dashboard tap "Reserve a Vehicle" (general), "Local Transport", "Outstation", "Book Goods Carrier", "Mini Truck Delivery", or "Bike Parcel". Goods options open the carrier flow with the vehicle type pre-selected.
2. **Choose locations** — set your pickup (defaults to current GPS) and drop. Use the address autocomplete (powered by Google Places) or pick from your saved addresses.
3. **Browse vehicles** — the reserve screen lists available vehicles in your city. Filter by type, AC/non-AC, etc.
4. **Confirm** — tap a vehicle to view details and fare. The confirmation sheet shows the estimated fare breakdown (base + distance + GST), payment method, and trip notes.
5. **Pay method** — only **Cash** is fully supported today. UPI, card, wallet, and net banking labels appear but no online payment gateway is wired up yet.
6. **Submit** — your booking is created and the driver gets notified. You'll see "Waiting for driver".
7. **OTP** — within seconds of booking creation, you'll receive a push notification with your 6-digit **Ride OTP**. The OTP is also shown on the Track Booking screen. **Share this OTP only with the driver assigned to you, after they physically arrive.**
8. **Track** — the Track Booking screen shows the driver's name, vehicle, and live location on the map.
9. **Trip** — once the driver verifies your OTP, the trip starts. You'll see "In progress".
10. **Completion** — the driver ends the trip. Pay the cash amount shown to the driver. The driver records the payment in their app.
11. **Rate** — leave a 1–5 star rating and optional comment.

## Cancellation policy

| When you cancel | Fee |
|---|---|
| Before driver accepts (`pending`) | Free |
| Within 2 minutes of driver acceptance | Free |
| More than 2 minutes after acceptance, before pickup | 20 % of the base fare |

You cannot cancel after the trip has started (`inProgress`).

## Saved addresses

From the drawer → "Saved Addresses". Tap "+" to add Home, Work, or Other. Saved addresses appear as quick-pick chips when entering pickup / drop.

## Ride history

Drawer → "Ride History" — paginated list of your past trips with status, fare, and driver. Tap a trip for the full breakdown.

## Offers & Rewards

Dashboard tile or drawer → "Offers & Rewards" — browse active promo codes. Tap a code to copy it; paste it in the fare-confirmation sheet to apply a discount (subject to validity).

## Support center

Drawer → "Support Center":

- **Raise a complaint** — choose priority (Low/Medium/High), describe the issue, optionally attach a screenshot. You'll get a ticket ID like `ZY-20260101-123`.
- **Send feedback** — leave a 1–5 star rating and message. You'll get a feedback ID like `FB-20260101-456`.

Both flow into the admin console for triage.

## Notifications

The app requests notification permission on first launch. If you deny it later, OTPs and trip updates will not push — you'll still see the OTP on the Track Booking screen.

To re-enable: device Settings → Apps → Zyppi Ride → Notifications → Allow.

## Sign out

Drawer → "Sign Out". Clears your session and unsubscribes you from push notifications.

## Privacy and data

The app stores some data on your device for offline access (Firestore cache, capped at 100 MB). Signing out does not currently clear this cache. If you sell or transfer your device, also clear app storage from system Settings.

Live location is shared **only** while a trip is active and **only** with the rider on that booking, the driver themselves, and Zyppi admins. The app does not track your location when no trip is active.

## Troubleshooting common rider issues

See [17 — Troubleshooting Guide](17-troubleshooting-guide.md).
