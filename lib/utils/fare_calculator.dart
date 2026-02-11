import '../models/booking_model.dart';
import '../models/available_vehicle_model.dart';

/// Utility class for calculating ride fares
class FareCalculator {
  /// Platform fee percentage
  static const double platformFeePercent = 5.0;

  /// GST percentage
  static const double gstPercent = 5.0;

  /// Cancellation fee percentage (of base fare)
  static const double cancellationFeePercent = 20.0;

  /// Night surcharge percentage (10 PM - 6 AM)
  static const double nightSurchargePercent = 10.0;

  /// Peak hour surcharge percentage
  static const double peakHourSurchargePercent = 15.0;

  /// Calculate fare for a ride
  static FareDetails calculateFare({
    required PricingInfo pricing,
    required double distanceKm,
    int durationMinutes = 0,
    double waitingMinutes = 0,
    double tollCharges = 0,
    String? promoCode,
    double? promoDiscountPercent,
    bool isNightTime = false,
    bool isPeakHour = false,
  }) {
    // Base fare
    double baseFare = pricing.basePrice;

    // Distance fare
    double distanceFare = distanceKm * pricing.perKmRate;

    // Time fare (per minute rate if applicable)
    double perMinuteRate = pricing.perHourRate / 60;
    double timeFare = durationMinutes * perMinuteRate;

    // Waiting charges (₹2 per minute after first 3 minutes)
    double freeWaitingMinutes = 3;
    double waitingCharges = 0;
    if (waitingMinutes > freeWaitingMinutes) {
      waitingCharges = (waitingMinutes - freeWaitingMinutes) * 2;
    }

    // Subtotal before surcharges
    double subtotal = baseFare + distanceFare + timeFare + waitingCharges + tollCharges;

    // Apply night surcharge if applicable
    if (isNightTime) {
      subtotal += subtotal * (nightSurchargePercent / 100);
    }

    // Apply peak hour surcharge if applicable
    if (isPeakHour) {
      subtotal += subtotal * (peakHourSurchargePercent / 100);
    }

    // Calculate GST
    double gstAmount = (subtotal * gstPercent) / 100;

    // Calculate promo discount
    double promoDiscount = 0;
    if (promoDiscountPercent != null && promoDiscountPercent > 0) {
      promoDiscount = (subtotal * promoDiscountPercent) / 100;
      // Cap promo discount at 50% of fare
      if (promoDiscount > subtotal * 0.5) {
        promoDiscount = subtotal * 0.5;
      }
    }

    // Total fare
    double totalFare = subtotal + gstAmount - promoDiscount;

    // Ensure minimum fare
    if (totalFare < pricing.minimumFare) {
      totalFare = pricing.minimumFare;
    }

    return FareDetails(
      baseFare: baseFare,
      distanceFare: distanceFare,
      timeFare: timeFare,
      waitingCharges: waitingCharges,
      tollCharges: tollCharges,
      gstAmount: gstAmount,
      discount: promoDiscount,
      totalFare: totalFare,
      promoCode: promoCode,
      promoDiscount: promoDiscount > 0 ? promoDiscount : null,
    );
  }

  /// Calculate estimated fare for booking preview
  static FareEstimate getEstimate({
    required PricingInfo pricing,
    required double distanceKm,
    int estimatedDurationMinutes = 0,
  }) {
    // Calculate low and high estimates
    final lowFare = calculateFare(
      pricing: pricing,
      distanceKm: distanceKm,
      durationMinutes: estimatedDurationMinutes,
    );

    // High estimate includes potential traffic delays (20% more time)
    final highFare = calculateFare(
      pricing: pricing,
      distanceKm: distanceKm,
      durationMinutes: (estimatedDurationMinutes * 1.2).round(),
      waitingMinutes: 5, // Assume some waiting
    );

    return FareEstimate(
      lowEstimate: lowFare.totalFare,
      highEstimate: highFare.totalFare,
      baseFare: pricing.basePrice,
      perKmRate: pricing.perKmRate,
      estimatedDistance: distanceKm,
      estimatedDuration: estimatedDurationMinutes,
    );
  }

  /// Calculate cancellation fee
  static double calculateCancellationFee({
    required double baseFare,
    required BookingStatus bookingStatus,
    DateTime? confirmedAt,
  }) {
    // No fee if booking was never confirmed
    if (bookingStatus == BookingStatus.pending) {
      return 0;
    }

    // If confirmed within last 2 minutes, no fee
    if (confirmedAt != null) {
      final timeSinceConfirm = DateTime.now().difference(confirmedAt);
      if (timeSinceConfirm.inMinutes < 2) {
        return 0;
      }
    }

    // Standard cancellation fee
    return baseFare * (cancellationFeePercent / 100);
  }

  /// Check if current time is night time (10 PM - 6 AM)
  static bool isNightTime([DateTime? dateTime]) {
    final time = dateTime ?? DateTime.now();
    return time.hour >= 22 || time.hour < 6;
  }

  /// Check if current time is peak hour (8-10 AM or 5-8 PM on weekdays)
  static bool isPeakHour([DateTime? dateTime]) {
    final time = dateTime ?? DateTime.now();

    // Only weekdays
    if (time.weekday == DateTime.saturday || time.weekday == DateTime.sunday) {
      return false;
    }

    // Morning peak: 8 AM - 10 AM
    if (time.hour >= 8 && time.hour < 10) {
      return true;
    }

    // Evening peak: 5 PM - 8 PM
    if (time.hour >= 17 && time.hour < 20) {
      return true;
    }

    return false;
  }

  /// Format fare amount as currency string
  static String formatFare(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  /// Format fare range as string
  static String formatFareRange(double low, double high) {
    if ((high - low).abs() < 10) {
      return formatFare((low + high) / 2);
    }
    return '${formatFare(low)} - ${formatFare(high)}';
  }

  /// Calculate driver earnings (after platform commission)
  static double calculateDriverEarnings(double totalFare) {
    final platformFee = totalFare * (platformFeePercent / 100);
    return totalFare - platformFee;
  }

  /// Get fare breakdown as list for display
  static List<FareBreakdownItem> getFareBreakdown(FareDetails fareDetails) {
    final items = <FareBreakdownItem>[];

    items.add(FareBreakdownItem(
      label: 'Base Fare',
      amount: fareDetails.baseFare,
    ));

    items.add(FareBreakdownItem(
      label: 'Distance Fare',
      amount: fareDetails.distanceFare,
    ));

    if (fareDetails.timeFare > 0) {
      items.add(FareBreakdownItem(
        label: 'Time Fare',
        amount: fareDetails.timeFare,
      ));
    }

    if (fareDetails.waitingCharges > 0) {
      items.add(FareBreakdownItem(
        label: 'Waiting Charges',
        amount: fareDetails.waitingCharges,
      ));
    }

    if (fareDetails.tollCharges > 0) {
      items.add(FareBreakdownItem(
        label: 'Toll Charges',
        amount: fareDetails.tollCharges,
      ));
    }

    if (fareDetails.gstAmount > 0) {
      items.add(FareBreakdownItem(
        label: 'GST (5%)',
        amount: fareDetails.gstAmount,
      ));
    }

    if (fareDetails.discount > 0) {
      items.add(FareBreakdownItem(
        label: fareDetails.promoCode != null
            ? 'Promo (${fareDetails.promoCode})'
            : 'Discount',
        amount: -fareDetails.discount,
        isDiscount: true,
      ));
    }

    return items;
  }
}

/// Fare estimate result
class FareEstimate {
  final double lowEstimate;
  final double highEstimate;
  final double baseFare;
  final double perKmRate;
  final double estimatedDistance;
  final int estimatedDuration;

  const FareEstimate({
    required this.lowEstimate,
    required this.highEstimate,
    required this.baseFare,
    required this.perKmRate,
    required this.estimatedDistance,
    required this.estimatedDuration,
  });

  double get averageEstimate => (lowEstimate + highEstimate) / 2;

  String get formattedRange =>
      FareCalculator.formatFareRange(lowEstimate, highEstimate);

  String get formattedAverage => FareCalculator.formatFare(averageEstimate);
}

/// Fare breakdown item for display
class FareBreakdownItem {
  final String label;
  final double amount;
  final bool isDiscount;

  const FareBreakdownItem({
    required this.label,
    required this.amount,
    this.isDiscount = false,
  });

  String get formattedAmount {
    if (isDiscount) {
      return '-${FareCalculator.formatFare(amount.abs())}';
    }
    return FareCalculator.formatFare(amount);
  }
}
