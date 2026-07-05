import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';
import '../models/driver_availability.dart';

final availabilityProvider = StateNotifierProvider.family<AvailabilityNotifier, AsyncValue<DriverAvailability>, String>(
      (ref, vehicleId) => AvailabilityNotifier(vehicleId),
);

class AvailabilityNotifier extends StateNotifier<AsyncValue<DriverAvailability>> {
  final String vehicleId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AvailabilityNotifier(this.vehicleId) : super(const AsyncValue.loading()) {
    loadAvailability();
  }

  // Load availability from Firestore
  Future<void> loadAvailability() async {
    state = const AsyncValue.loading();
    AppLogger.firestore('GET', 'vehicles/$vehicleId/settings', docId: 'availability');

    try {
      final doc = await _firestore
          .collection(TestMode.vehiclesCollection)
          .doc(vehicleId)
          .collection('settings')
          .doc('availability')
          .get();

      if (doc.exists) {
        final availability = DriverAvailability.fromJson(doc.data()!);
        AppLogger.success('Loaded availability for vehicle: $vehicleId');
        state = AsyncValue.data(availability);
      } else {
        AppLogger.info('No availability found, creating initial settings');
        final initial = DriverAvailability.initial();
        await _firestore
            .collection(TestMode.vehiclesCollection)
            .doc(vehicleId)
            .collection('settings')
            .doc('availability')
            .set(initial.toJson());
        state = AsyncValue.data(initial);
      }
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'loadAvailability');
      state = AsyncValue.error(exception, stackTrace);
    }
  }

  // Toggle date (kept for compatibility)
  void toggleDate(String dateString) {
    state.whenData((availability) {
      final blockedDates = List<String>.from(availability.blockedDates);

      if (blockedDates.contains(dateString)) {
        blockedDates.remove(dateString);
      } else {
        blockedDates.add(dateString);
      }

      state = AsyncValue.data(availability.copyWith(
        blockedDates: blockedDates,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Block a specific date
  void blockDate(String dateString) {
    state.whenData((availability) {
      final blockedDates = List<String>.from(availability.blockedDates);

      if (!blockedDates.contains(dateString)) {
        blockedDates.add(dateString);
        blockedDates.sort();
      }

      state = AsyncValue.data(availability.copyWith(
        blockedDates: blockedDates,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Unblock a specific date
  void unblockDate(String dateString) {
    state.whenData((availability) {
      final blockedDates = List<String>.from(availability.blockedDates);
      blockedDates.remove(dateString);

      state = AsyncValue.data(availability.copyWith(
        blockedDates: blockedDates,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update working mode
  void updateWorkingMode(String mode, {CustomHours? customHours}) {
    state.whenData((availability) {
      state = AsyncValue.data(availability.copyWith(
        workingMode: mode,
        customHours: customHours,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update trip preferences (whole object)
  void updateTripPreferences(TripPreferences tripPreferences) {
    state.whenData((availability) {
      state = AsyncValue.data(availability.copyWith(
        tripPreferences: tripPreferences,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update vehicle preferences (whole object)
  void updateVehiclePreferences(VehiclePreferences vehiclePreferences) {
    state.whenData((availability) {
      state = AsyncValue.data(availability.copyWith(
        vehiclePreferences: vehiclePreferences,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update individual trip preference
  // Update individual trip preference
  void updateTripPreference(String preferenceType, Map<String, dynamic> value) {
    state.whenData((availability) {
      final current = availability.tripPreferences;
      TripPreferences updatedPreferences;

      switch (preferenceType) {
        case 'weddingBookings':
          updatedPreferences = TripPreferences(
            weddingBookings: BookingType.fromJson(value),  // ✅ FIXED: Convert from JSON
            longDistance: current.longDistance,
            outstationTrips: current.outstationTrips,
            oneWayTrip: current.oneWayTrip,
            roundTrip: current.roundTrip,
            weekendBookings: current.weekendBookings,
          );
          break;

        case 'longDistance':
          updatedPreferences = TripPreferences(
            weddingBookings: current.weddingBookings,
            longDistance: LongDistanceConfig.fromJson(value),  // ✅ FIXED
            outstationTrips: current.outstationTrips,
            oneWayTrip: current.oneWayTrip,
            roundTrip: current.roundTrip,
            weekendBookings: current.weekendBookings,
          );
          break;

        case 'outstationTrips':
          updatedPreferences = TripPreferences(
            weddingBookings: current.weddingBookings,
            longDistance: current.longDistance,
            outstationTrips: OutstationConfig.fromJson(value),  // ✅ FIXED
            oneWayTrip: current.oneWayTrip,
            roundTrip: current.roundTrip,
            weekendBookings: current.weekendBookings,
          );
          break;

        case 'oneWayTrip':
          updatedPreferences = TripPreferences(
            weddingBookings: current.weddingBookings,
            longDistance: current.longDistance,
            outstationTrips: current.outstationTrips,
            oneWayTrip: OneWayConfig.fromJson(value),  // ✅ FIXED
            roundTrip: current.roundTrip,
            weekendBookings: current.weekendBookings,
          );
          break;

        case 'roundTrip':
          updatedPreferences = TripPreferences(
            weddingBookings: current.weddingBookings,
            longDistance: current.longDistance,
            outstationTrips: current.outstationTrips,
            oneWayTrip: current.oneWayTrip,
            roundTrip: RoundTripConfig.fromJson(value),  // ✅ FIXED
            weekendBookings: current.weekendBookings,
          );
          break;

        case 'weekendBookings':
          updatedPreferences = TripPreferences(
            weddingBookings: current.weddingBookings,
            longDistance: current.longDistance,
            outstationTrips: current.outstationTrips,
            oneWayTrip: current.oneWayTrip,
            roundTrip: current.roundTrip,
            weekendBookings: WeekendConfig.fromJson(value),  // ✅ FIXED
          );
          break;

        default:
          return;
      }

      state = AsyncValue.data(availability.copyWith(
        tripPreferences: updatedPreferences,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update individual vehicle preference
  void updateVehiclePreference(String key, dynamic value) {
    state.whenData((availability) {
      final currentPrefs = availability.vehiclePreferences;
      VehiclePreferences updatedPreferences;

      switch (key) {
        case 'maxPassengers':
          updatedPreferences = VehiclePreferences(
            maxPassengers: value as int,
            hasAC: currentPrefs.hasAC,
            hasMusic: currentPrefs.hasMusic,
            petFriendly: currentPrefs.petFriendly,
          );
          break;

        case 'hasAC':
          updatedPreferences = VehiclePreferences(
            maxPassengers: currentPrefs.maxPassengers,
            hasAC: value as bool,
            hasMusic: currentPrefs.hasMusic,
            petFriendly: currentPrefs.petFriendly,
          );
          break;

        case 'hasMusic':
          updatedPreferences = VehiclePreferences(
            maxPassengers: currentPrefs.maxPassengers,
            hasAC: currentPrefs.hasAC,
            hasMusic: value as bool,
            petFriendly: currentPrefs.petFriendly,
          );
          break;

        case 'petFriendly':
          updatedPreferences = VehiclePreferences(
            maxPassengers: currentPrefs.maxPassengers,
            hasAC: currentPrefs.hasAC,
            hasMusic: currentPrefs.hasMusic,
            petFriendly: value as bool,
          );
          break;

        default:
          return;
      }

      state = AsyncValue.data(availability.copyWith(
        vehiclePreferences: updatedPreferences,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update custom hours
  void updateCustomHours(String startTime, String endTime) {
    state.whenData((availability) {
      final customHours = CustomHours(
        startTime: startTime,
        endTime: endTime,
      );

      state = AsyncValue.data(availability.copyWith(
        workingMode: 'custom',
        customHours: customHours,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Update availability status
  void updateAvailabilityStatus(bool isAvailable) {
    state.whenData((availability) {
      state = AsyncValue.data(availability.copyWith(
        isCurrentlyAvailable: isAvailable,
        lastUpdated: DateTime.now(),
      ));
    });
  }

  // Save to Firestore
  Future<Result<void>> saveAvailability() async {
    AppLogger.firestore('SET', 'vehicles/$vehicleId/settings', docId: 'availability');

    try {
      final availability = state.value;
      if (availability == null) {
        final exception = ValidationException(
          message: 'No availability data to save',
          code: 'NO_DATA',
        );
        AppLogger.logException(exception, context: 'saveAvailability');
        return Result.failure(exception);
      }

      await _firestore
          .collection(TestMode.vehiclesCollection)
          .doc(vehicleId)
          .collection('settings')
          .doc('availability')
          .set(availability.toJson(), SetOptions(merge: true));

      AppLogger.success('Availability saved for vehicle: $vehicleId');

      final updated = availability.copyWith(lastUpdated: DateTime.now());
      state = AsyncValue.data(updated);

      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'saveAvailability', stackTrace: stackTrace);
      return Result.failure(exception);
    }
  }

  // Auto-save
  Future<void> autoSave() async {
    try {
      final availability = state.value;
      if (availability == null) return;

      await _firestore
          .collection(TestMode.vehiclesCollection)
          .doc(vehicleId)
          .collection('settings')
          .doc('availability')
          .set(availability.toJson(), SetOptions(merge: true));

      AppLogger.debug('Auto-saved availability for vehicle: $vehicleId');
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'autoSave');
      // Don't rethrow for auto-save - it's a background operation
    }
  }
}
