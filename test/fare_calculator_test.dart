import 'package:flutter_test/flutter_test.dart';
import 'package:zyppi_ride/models/available_vehicle_model.dart';
import 'package:zyppi_ride/models/booking_model.dart';
import 'package:zyppi_ride/utils/fare_calculator.dart';

void main() {
  // basePrice 50, ₹12/km, ₹60/hr (→ ₹1/min), minimum ₹100
  final pricing = PricingInfo(
    basePrice: 50,
    perKmRate: 12,
    perHourRate: 60,
    minimumFare: 100,
  );

  group('FareCalculator.calculateFare', () {
    test('base + distance + time + GST, no surcharges', () {
      final fare = FareCalculator.calculateFare(
        pricing: pricing,
        distanceKm: 10,
        durationMinutes: 20,
      );
      // subtotal = 50 + 120 + 20 = 190; GST 5% = 9.5
      expect(fare.baseFare, 50);
      expect(fare.distanceFare, 120);
      expect(fare.timeFare, 20);
      expect(fare.gstAmount, closeTo(9.5, 0.001));
      expect(fare.totalFare, closeTo(199.5, 0.001));
    });

    test('first 3 waiting minutes are free, ₹2/min after', () {
      final noCharge = FareCalculator.calculateFare(
        pricing: pricing,
        distanceKm: 10,
        waitingMinutes: 3,
      );
      expect(noCharge.waitingCharges, 0);

      final charged = FareCalculator.calculateFare(
        pricing: pricing,
        distanceKm: 10,
        waitingMinutes: 8,
      );
      expect(charged.waitingCharges, 10); // (8-3) * ₹2
    });

    test('night surcharge adds 10% to the subtotal', () {
      final day = FareCalculator.calculateFare(pricing: pricing, distanceKm: 10);
      final night = FareCalculator.calculateFare(
        pricing: pricing,
        distanceKm: 10,
        isNightTime: true,
      );
      // subtotal 170 → 187; GST on the surcharged subtotal
      expect(day.totalFare, closeTo(178.5, 0.001));
      expect(night.totalFare, closeTo(187 * 1.05, 0.001));
    });

    test('night + peak surcharges compound', () {
      final fare = FareCalculator.calculateFare(
        pricing: pricing,
        distanceKm: 10,
        isNightTime: true,
        isPeakHour: true,
      );
      final expectedSubtotal = 170 * 1.10 * 1.15;
      expect(fare.totalFare, closeTo(expectedSubtotal * 1.05, 0.001));
    });

    test('promo discount is capped at 50% of the subtotal', () {
      final fare = FareCalculator.calculateFare(
        pricing: pricing,
        distanceKm: 10,
        promoCode: 'BIG90',
        promoDiscountPercent: 90,
      );
      // subtotal 170 → discount capped at 85, not 153; the discounted
      // total (93.5) then hits the ₹100 minimum-fare floor.
      expect(fare.discount, closeTo(85, 0.001));
      expect(fare.totalFare, 100);
    });

    test('minimum fare floor applies to short trips', () {
      final fare = FareCalculator.calculateFare(pricing: pricing, distanceKm: 1);
      // 50 + 12 = 62 + GST 3.1 = 65.1 → floored to minimum 100
      expect(fare.totalFare, 100);
    });
  });

  group('time-window helpers', () {
    test('isNightTime covers 22:00–05:59 inclusive', () {
      expect(FareCalculator.isNightTime(DateTime(2026, 1, 5, 21, 59)), isFalse);
      expect(FareCalculator.isNightTime(DateTime(2026, 1, 5, 22, 0)), isTrue);
      expect(FareCalculator.isNightTime(DateTime(2026, 1, 5, 5, 59)), isTrue);
      expect(FareCalculator.isNightTime(DateTime(2026, 1, 5, 6, 0)), isFalse);
    });

    test('isPeakHour: weekday rush windows only', () {
      // Monday 2026-01-05
      expect(FareCalculator.isPeakHour(DateTime(2026, 1, 5, 8, 0)), isTrue);
      expect(FareCalculator.isPeakHour(DateTime(2026, 1, 5, 9, 59)), isTrue);
      expect(FareCalculator.isPeakHour(DateTime(2026, 1, 5, 10, 0)), isFalse);
      expect(FareCalculator.isPeakHour(DateTime(2026, 1, 5, 17, 0)), isTrue);
      expect(FareCalculator.isPeakHour(DateTime(2026, 1, 5, 20, 0)), isFalse);
      // Saturday morning rush hour is not peak
      expect(FareCalculator.isPeakHour(DateTime(2026, 1, 10, 8, 30)), isFalse);
    });
  });

  group('cancellation fee', () {
    test('no fee for never-confirmed bookings', () {
      expect(
        FareCalculator.calculateCancellationFee(
          baseFare: 50,
          bookingStatus: BookingStatus.pending,
        ),
        0,
      );
    });

    test('grace period: no fee within 2 minutes of confirmation', () {
      expect(
        FareCalculator.calculateCancellationFee(
          baseFare: 50,
          bookingStatus: BookingStatus.confirmed,
          confirmedAt: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
        0,
      );
    });

    test('20% of base fare after the grace period', () {
      expect(
        FareCalculator.calculateCancellationFee(
          baseFare: 50,
          bookingStatus: BookingStatus.confirmed,
          confirmedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        10,
      );
    });
  });

  group('driver earnings and formatting', () {
    test('platform keeps 5%', () {
      expect(FareCalculator.calculateDriverEarnings(200), 190);
    });

    test('formatFare rounds to whole rupees', () {
      expect(FareCalculator.formatFare(199.5), '₹200');
    });

    test('formatFareRange collapses near-equal estimates', () {
      expect(FareCalculator.formatFareRange(100, 105), '₹103');
      expect(FareCalculator.formatFareRange(100, 140), '₹100 - ₹140');
    });
  });

  group('FareDetails.calculate (booking pipeline)', () {
    test('GST and promo discount arithmetic', () {
      final fare = FareDetails.calculate(
        baseFare: 50,
        perKmRate: 12,
        distanceKm: 10,
        promoCode: 'SAVE20',
        promoDiscount: 20,
      );
      // subtotal 170, GST 8.5, promo -20
      expect(fare.gstAmount, closeTo(8.5, 0.001));
      expect(fare.discount, closeTo(20, 0.001));
      expect(fare.totalFare, closeTo(158.5, 0.001));
      expect(fare.promoCode, 'SAVE20');
    });

    test('map round-trip preserves totals', () {
      final fare = FareDetails.calculate(
        baseFare: 50,
        perKmRate: 12,
        distanceKm: 10,
        tollCharges: 40,
      );
      final restored = FareDetails.fromMap(fare.toMap());
      expect(restored.totalFare, closeTo(fare.totalFare, 0.001));
      expect(restored.tollCharges, 40);
    });
  });
}
