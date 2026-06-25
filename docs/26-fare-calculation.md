# 26 — Fare Calculation Documentation

The pricing engine lives in **two places** that must be kept in sync:

1. `lib/utils/fare_calculator.dart` — the **richer** calculator with surcharges, cancellation, driver earnings, formatting, and breakdown.
2. `FareDetails.calculate` constructor in `lib/models/booking_model.dart` — a **simpler** calculator embedded in the model; used by `BookingService.createBooking` and `completeTrip`.

Both compute a `FareDetails` object that is persisted to `bookings/{id}.fareDetails`. The richer calculator should be used wherever surcharges apply; the simpler one currently runs in the booking lifecycle.

## Inputs

| Input | From | Notes |
|---|---|---|
| `basePrice` | `vehicles/{id}.pricing.basePrice` | Driver-configured at registration |
| `perKmRate` | `vehicles/{id}.pricing.perKmRate` | Same |
| `perHourRate` | `vehicles/{id}.pricing.perHourRate` | Same; divided by 60 to get per-minute |
| `minimumFare` | `vehicles/{id}.pricing.minimumFare` | Floor |
| `distanceKm` | client estimate (booking) / driver-entered actual (completion) | km |
| `durationMinutes` | client / driver actual | minutes |
| `waitingMinutes` | driver actual | minutes; first 3 free, then ₹2/min |
| `tollCharges` | driver actual | pass-through |
| `promoCode` | rider input | upper-cased and looked up in `offers` |
| `promoDiscountPercent` | from `offers/{id}.discount` | percent of subtotal |
| `isNightTime` | `FareCalculator.isNightTime(now)` | `hour >= 22 || hour < 6` |
| `isPeakHour` | `FareCalculator.isPeakHour(now)` | weekdays 08:00–10:00 or 17:00–20:00 |

## Output (`FareDetails`)

| Field | Computation |
|---|---|
| `baseFare` | `pricing.basePrice` |
| `distanceFare` | `distanceKm × perKmRate` |
| `timeFare` | `durationMinutes × (perHourRate / 60)` |
| `waitingCharges` | `max(0, waitingMinutes − 3) × 2` |
| `tollCharges` | pass-through |
| `gstAmount` | `5%` of subtotal (after surcharges) |
| `discount` | absolute promo discount |
| `totalFare` | `subtotal + gst − discount`, then `max(minimumFare)` |
| `promoCode` | echoed |
| `promoDiscount` | absolute |

## Constants (in `FareCalculator`)

| Constant | Value | Use |
|---|---|---|
| `platformFeePercent` | 5.0 | Deducted from driver earnings (not from rider charge) |
| `gstPercent` | 5.0 | Added on top of subtotal |
| `cancellationFeePercent` | 20.0 | 20% of base fare (applied if cancellation conditions met) |
| `nightSurchargePercent` | 10.0 | 22:00–06:00 |
| `peakHourSurchargePercent` | 15.0 | Mon–Fri 08:00–10:00, 17:00–20:00 |

## Formula (full — from `FareCalculator.calculateFare`)

```text
let bf = basePrice
let df = distanceKm × perKmRate
let tf = durationMinutes × (perHourRate / 60)
let wc = max(0, waitingMinutes − 3) × 2
let subtotal = bf + df + tf + wc + tollCharges

if isNightTime:  subtotal *= 1.10
if isPeakHour:   subtotal *= 1.15

let gst = subtotal × 0.05
let promo = subtotal × (promoDiscountPercent / 100)
if promo > subtotal × 0.5:  promo = subtotal × 0.5   # cap at 50%

let total = subtotal + gst − promo
if total < minimumFare:  total = minimumFare
```

> ⚠️ **Surcharges are multiplicative.** Night and peak surcharges compound (`× 1.10 × 1.15 = ×1.265`). If your business rule is "max of the two", you must change the formula.

## Formula (lite — from `FareDetails.calculate` in booking_model.dart)

```text
let df = distanceKm × perKmRate
let tf = durationMinutes × perMinuteRate    # caller passes rate
let wc = waitingMinutes × waitingPerMinute  # default 2/min; NO 3-min free window
let subtotal = basePrice + df + tf + wc + tollCharges
let gst = subtotal × gstPercent/100         # default 5%
let total = subtotal + gst − (discount + promoDiscount)
total = max(total, 0)
```

**Differences vs the full calculator:**
- No surcharges (night / peak).
- No 3-minute free waiting window — every waiting minute is charged.
- No minimum fare floor.
- No promo cap.

Because `BookingService` uses the lite version today, **surcharges and free waiting are not actually applied in production** despite living in the codebase. To enable them, switch `BookingService.createBooking` and `completeTrip` to call `FareCalculator.calculateFare` instead.

## Worked example (lite path — current production)

Inputs: city ride at 14:30 (no surcharges), distance 8 km, duration 20 min, no waiting, no toll, no promo, vehicle `{basePrice: 50, perKmRate: 12, perHourRate: 240, minimumFare: 80}`.

| Component | Value |
|---|---|
| baseFare | 50 |
| distanceFare | `8 × 12 = 96` |
| timeFare | `20 × (240/60) = 80` *(only applied if caller passes perMinuteRate)* |
| waitingCharges | 0 |
| tollCharges | 0 |
| subtotal | `50 + 96 + 80 = 226` |
| gstAmount | `226 × 0.05 = 11.30` |
| discount | 0 |
| **totalFare** | **237.30** |

Driver earnings: `237.30 × (1 − 0.05) = 225.43`. Platform earns `237.30 − 225.43 = 11.87`.

## Worked example (full path with surcharges — what *should* happen at 22:30 in Mumbai)

Same inputs at 22:30 (night surcharge applies):

| Component | Value |
|---|---|
| baseFare | 50 |
| distanceFare | 96 |
| timeFare | 80 |
| waitingCharges | 0 (assuming ≤ 3 min wait) |
| tollCharges | 0 |
| subtotal raw | 226 |
| after night surcharge | `226 × 1.10 = 248.60` |
| gst | `248.60 × 0.05 = 12.43` |
| **totalFare** | **261.03** |

Net rider pays ~₹24 more at night. (At peak hour during weekday: ~₹35 more.)

## Cancellation fee

| Function | Behaviour |
|---|---|
| `FareCalculator.calculateCancellationFee({baseFare, bookingStatus, confirmedAt})` | Returns 0 if `pending`; 0 if `confirmed` and < 2 min from `confirmedAt`; else `baseFare × 0.20`. |
| `BookingService.cancelBooking` (production) | Returns `baseFare × 0.20` if status was `confirmed` — does **not** apply the 2-minute grace window. |

This inconsistency between the model layer and the service is a known cleanup target; pick one source of truth.

## Formatting helpers

| Helper | Behaviour |
|---|---|
| `FareCalculator.formatFare(x)` | `'₹' + x.toStringAsFixed(0)` |
| `FareCalculator.formatFareRange(low, high)` | Single value if `|high-low| < 10`, else `'₹L - ₹H'` |
| `FareCalculator.getFareBreakdown(fareDetails)` | List of `FareBreakdownItem` for UI display (Base, Distance, Time if > 0, Waiting if > 0, Toll if > 0, GST if > 0, Discount if > 0 — last one rendered as negative) |

## Fare estimate (preview before booking)

`FareCalculator.getEstimate({pricing, distanceKm, estimatedDurationMinutes})` returns a `FareEstimate` with a low/high range. The high estimate assumes 20 % more time and 5 minutes of waiting. Display as `formattedRange` ("₹220 - ₹260") for a more honest preview than a single number.

## Promo code resolution

`BookingService._getPromoDiscount(promoCode)`:

1. Upper-cases the code.
2. Queries `offers where code == X AND isActive == true` (composite index exists), limit 1.
3. Returns `offer.discount` as a `double` or `null`.

> Important: the lite calculator (`FareDetails.calculate`) treats `promoDiscount` as an **absolute** amount in rupees, not a percentage. The richer calculator treats `promoDiscountPercent` as a percentage. Make sure your `offers/{id}.discount` is stored consistently — today this depends on which calculator the codebase ends up using.

## Driver earnings

```dart
static double calculateDriverEarnings(double totalFare) {
  final platformFee = totalFare * (platformFeePercent / 100);  // 5%
  return totalFare - platformFee;
}
```

So the rider pays `totalFare` (inclusive of 5 % GST); the platform takes 5 % of that; the driver receives 95 % of the rider's payment. **No taxes are withheld** by the platform; drivers are responsible for their own GST filing.

## Currency and rounding

- Currency: `₹` only (hardcoded). To support multi-currency, parameterise via `pricing.currency` or app config.
- Rounding: all internal math is `double`; display uses `toStringAsFixed(0)` (no decimals shown). For Indian markets that's acceptable; for some currencies you'd want 2 decimals.

## Testing fare math

`FareCalculator` is pure (no I/O), so it's the cheapest, highest-coverage place to add unit tests. Recommended cases:

- Base + distance only, no surcharges (the lite path).
- Night surcharge at 23:00.
- Peak surcharge at 09:30 weekday vs 09:30 weekend (should *not* surcharge weekend).
- Promo cap at 50 %.
- Minimum-fare floor.
- Cancellation fee at 1 min vs 5 min after confirmation.

A test file `test/fare_calculator_test.dart` would catch the surcharges-not-applied gap mentioned above.
