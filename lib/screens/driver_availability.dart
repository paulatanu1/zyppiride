import 'package:cloud_firestore/cloud_firestore.dart';

class DriverAvailability {
  final List<String> blockedDates;
  final Map<String, LimitedAvailability> limitedDates;
  final String workingMode; // 'always_available', 'day_shift', 'night_shift', 'custom'
  final CustomHours? customHours;
  final TripPreferences tripPreferences;
  final VehiclePreferences vehiclePreferences;
  final DateTime lastUpdated;
  final bool isCurrentlyAvailable;

  DriverAvailability({
    required this.blockedDates,
    required this.limitedDates,
    required this.workingMode,
    this.customHours,
    required this.tripPreferences,
    required this.vehiclePreferences,
    required this.lastUpdated,
    required this.isCurrentlyAvailable,
  });

  factory DriverAvailability.initial() {
    return DriverAvailability(
      blockedDates: [],
      limitedDates: {},
      workingMode: 'always_available',
      customHours: null,
      tripPreferences: TripPreferences.initial(),
      vehiclePreferences: VehiclePreferences.initial(),
      lastUpdated: DateTime.now(),
      isCurrentlyAvailable: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blockedDates': blockedDates,
      'limitedDates': limitedDates.map((key, value) => MapEntry(key, value.toJson())),
      'workingMode': workingMode,
      'customHours': customHours?.toJson(),
      'tripPreferences': tripPreferences.toJson(),
      'vehiclePreferences': vehiclePreferences.toJson(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isCurrentlyAvailable': isCurrentlyAvailable,
    };
  }

  factory DriverAvailability.fromJson(Map<String, dynamic> json) {
    return DriverAvailability(
      blockedDates: List<String>.from(json['blockedDates'] ?? []),
      limitedDates: (json['limitedDates'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, LimitedAvailability.fromJson(value)),
      ) ?? {},
      workingMode: json['workingMode'] ?? 'always_available',
      customHours: json['customHours'] != null 
          ? CustomHours.fromJson(json['customHours']) 
          : null,
      tripPreferences: TripPreferences.fromJson(json['tripPreferences']),
      vehiclePreferences: VehiclePreferences.fromJson(json['vehiclePreferences']),
      lastUpdated: (json['lastUpdated'] as Timestamp).toDate(),
      isCurrentlyAvailable: json['isCurrentlyAvailable'] ?? true,
    );
  }
}

class LimitedAvailability {
  final String startTime;
  final String endTime;
  final String? reason;

  LimitedAvailability({
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'endTime': endTime,
    'reason': reason,
  };

  factory LimitedAvailability.fromJson(Map<String, dynamic> json) {
    return LimitedAvailability(
      startTime: json['startTime'],
      endTime: json['endTime'],
      reason: json['reason'],
    );
  }
}

class CustomHours {
  final String startTime;
  final String endTime;

  CustomHours({required this.startTime, required this.endTime});

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'endTime': endTime,
  };

  factory CustomHours.fromJson(Map<String, dynamic> json) {
    return CustomHours(
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }
}

class TripPreferences {
  final BookingType weddingBookings;
  final LongDistanceConfig longDistance;
  final OutstationConfig outstationTrips;
  final OneWayConfig oneWayTrip;
  final RoundTripConfig roundTrip;
  final WeekendConfig weekendBookings;

  TripPreferences({
    required this.weddingBookings,
    required this.longDistance,
    required this.outstationTrips,
    required this.oneWayTrip,
    required this.roundTrip,
    required this.weekendBookings,
  });

  factory TripPreferences.initial() {
    return TripPreferences(
      weddingBookings: BookingType(enabled: false, minAdvanceBooking: 3, fareMultiplier: 1.5),
      longDistance: LongDistanceConfig(enabled: true, maxDistance: 500, overnightStay: true),
      outstationTrips: OutstationConfig(enabled: true, minDistance: 200),
      oneWayTrip: OneWayConfig(enabled: true, returnCharges: 'half_fare'),
      roundTrip: RoundTripConfig(enabled: true, waitingCharges: 50),
      weekendBookings: WeekendConfig(enabled: true, fareMultiplier: 1.2),
    );
  }

  Map<String, dynamic> toJson() => {
    'weddingBookings': weddingBookings.toJson(),
    'longDistance': longDistance.toJson(),
    'outstationTrips': outstationTrips.toJson(),
    'oneWayTrip': oneWayTrip.toJson(),
    'roundTrip': roundTrip.toJson(),
    'weekendBookings': weekendBookings.toJson(),
  };

  factory TripPreferences.fromJson(Map<String, dynamic> json) {
    return TripPreferences(
      weddingBookings: BookingType.fromJson(json['weddingBookings']),
      longDistance: LongDistanceConfig.fromJson(json['longDistance']),
      outstationTrips: OutstationConfig.fromJson(json['outstationTrips']),
      oneWayTrip: OneWayConfig.fromJson(json['oneWayTrip']),
      roundTrip: RoundTripConfig.fromJson(json['roundTrip']),
      weekendBookings: WeekendConfig.fromJson(json['weekendBookings']),
    );
  }
}

class BookingType {
  final bool enabled;
  final int minAdvanceBooking;
  final double fareMultiplier;

  BookingType({
    required this.enabled,
    required this.minAdvanceBooking,
    required this.fareMultiplier,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minAdvanceBooking': minAdvanceBooking,
    'fareMultiplier': fareMultiplier,
  };

  factory BookingType.fromJson(Map<String, dynamic> json) {
    return BookingType(
      enabled: json['enabled'] ?? false,
      minAdvanceBooking: json['minAdvanceBooking'] ?? 3,
      fareMultiplier: (json['fareMultiplier'] ?? 1.5).toDouble(),
    );
  }
}

class LongDistanceConfig {
  final bool enabled;
  final int maxDistance;
  final bool overnightStay;

  LongDistanceConfig({
    required this.enabled,
    required this.maxDistance,
    required this.overnightStay,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'maxDistance': maxDistance,
    'overnightStay': overnightStay,
  };

  factory LongDistanceConfig.fromJson(Map<String, dynamic> json) {
    return LongDistanceConfig(
      enabled: json['enabled'] ?? true,
      maxDistance: json['maxDistance'] ?? 500,
      overnightStay: json['overnightStay'] ?? true,
    );
  }
}

class OutstationConfig {
  final bool enabled;
  final int minDistance;

  OutstationConfig({required this.enabled, required this.minDistance});

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minDistance': minDistance,
  };

  factory OutstationConfig.fromJson(Map<String, dynamic> json) {
    return OutstationConfig(
      enabled: json['enabled'] ?? true,
      minDistance: json['minDistance'] ?? 200,
    );
  }
}

class OneWayConfig {
  final bool enabled;
  final String returnCharges; // 'half_fare', 'full_fare', 'negotiable'

  OneWayConfig({required this.enabled, required this.returnCharges});

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'returnCharges': returnCharges,
  };

  factory OneWayConfig.fromJson(Map<String, dynamic> json) {
    return OneWayConfig(
      enabled: json['enabled'] ?? true,
      returnCharges: json['returnCharges'] ?? 'half_fare',
    );
  }
}

class RoundTripConfig {
  final bool enabled;
  final int waitingCharges;

  RoundTripConfig({required this.enabled, required this.waitingCharges});

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'waitingCharges': waitingCharges,
  };

  factory RoundTripConfig.fromJson(Map<String, dynamic> json) {
    return RoundTripConfig(
      enabled: json['enabled'] ?? true,
      waitingCharges: json['waitingCharges'] ?? 50,
    );
  }
}

class WeekendConfig {
  final bool enabled;
  final double fareMultiplier;

  WeekendConfig({required this.enabled, required this.fareMultiplier});

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'fareMultiplier': fareMultiplier,
  };

  factory WeekendConfig.fromJson(Map<String, dynamic> json) {
    return WeekendConfig(
      enabled: json['enabled'] ?? true,
      fareMultiplier: (json['fareMultiplier'] ?? 1.2).toDouble(),
    );
  }
}

class VehiclePreferences {
  final int maxPassengers;
  final bool hasAC;
  final bool hasMusic;
  final bool petFriendly;

  VehiclePreferences({
    required this.maxPassengers,
    required this.hasAC,
    required this.hasMusic,
    required this.petFriendly,
  });

  factory VehiclePreferences.initial() {
    return VehiclePreferences(
      maxPassengers: 4,
      hasAC: true,
      hasMusic: true,
      petFriendly: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxPassengers': maxPassengers,
    'hasAC': hasAC,
    'hasMusic': hasMusic,
    'petFriendly': petFriendly,
  };

  factory VehiclePreferences.fromJson(Map<String, dynamic> json) {
    return VehiclePreferences(
      maxPassengers: json['maxPassengers'] ?? 4,
      hasAC: json['hasAC'] ?? true,
      hasMusic: json['hasMusic'] ?? true,
      petFriendly: json['petFriendly'] ?? false,
    );
  }
}
