import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    try {
      final doc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .collection('settings')
          .doc('availability')
          .get();

      if (doc.exists) {
        final availability = DriverAvailability.fromJson(doc.data()!);
        state = AsyncValue.data(availability);
      } else {
        final initial = DriverAvailability.initial();
        await _firestore
            .collection('vehicles')
            .doc(vehicleId)
            .collection('settings')
            .doc('availability')
            .set(initial.toJson());
        state = AsyncValue.data(initial);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
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

      final updated = DriverAvailability(
        blockedDates: blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
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

      final updated = DriverAvailability(
        blockedDates: blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Unblock a specific date
  void unblockDate(String dateString) {
    state.whenData((availability) {
      final blockedDates = List<String>.from(availability.blockedDates);
      blockedDates.remove(dateString);

      final updated = DriverAvailability(
        blockedDates: blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Update working mode
  void updateWorkingMode(String mode, {CustomHours? customHours}) {
    state.whenData((availability) {
      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: mode,
        customHours: customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Update trip preferences (whole object)
  void updateTripPreferences(TripPreferences tripPreferences) {
    state.whenData((availability) {
      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Update vehicle preferences (whole object)
  void updateVehiclePreferences(VehiclePreferences vehiclePreferences) {
    state.whenData((availability) {
      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
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

      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: updatedPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
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

      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: updatedPreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Update custom hours
  void updateCustomHours(String startTime, String endTime) {
    state.whenData((availability) {
      final customHours = CustomHours(
        startTime: startTime,
        endTime: endTime,
      );

      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: 'custom',
        customHours: customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Update availability status
  void updateAvailabilityStatus(bool isAvailable) {
    state.whenData((availability) {
      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: isAvailable,
      );

      state = AsyncValue.data(updated);
    });
  }

  // Save to Firestore
  Future<void> saveAvailability() async {
    try {
      final availability = state.value;
      if (availability == null) {
        throw Exception('No availability data to save');
      }

      await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .collection('settings')
          .doc('availability')
          .set(availability.toJson(), SetOptions(merge: true));

      print('✅ Availability saved successfully!');

      final updated = DriverAvailability(
        blockedDates: availability.blockedDates,
        limitedDates: availability.limitedDates,
        workingMode: availability.workingMode,
        customHours: availability.customHours,
        tripPreferences: availability.tripPreferences,
        vehiclePreferences: availability.vehiclePreferences,
        lastUpdated: DateTime.now(),
        isCurrentlyAvailable: availability.isCurrentlyAvailable,
      );

      state = AsyncValue.data(updated);
    } catch (e, stackTrace) {
      print('❌ Error saving availability: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Auto-save
  Future<void> autoSave() async {
    try {
      final availability = state.value;
      if (availability == null) return;

      await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .collection('settings')
          .doc('availability')
          .set(availability.toJson(), SetOptions(merge: true));

      print('💾 Auto-saved to Firestore');
    } catch (e) {
      print('❌ Auto-save failed: $e');
    }
  }
}
