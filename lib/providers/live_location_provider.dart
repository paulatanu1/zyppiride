import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_logger.dart';
import '../models/driver_location_model.dart';
import '../services/live_location_service.dart';

// ============================================
// SERVICE PROVIDER
// ============================================

/// Provider for LiveLocationService instance
final liveLocationServiceProvider = Provider<LiveLocationService>((ref) {
  final service = LiveLocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ============================================
// TRACKING STATE
// ============================================

/// State for driver location tracking
class LocationTrackingState {
  final bool isTracking;
  final bool isLoading;
  final String? activeBookingId;
  final DriverLocationData? lastLocation;
  final String? error;

  const LocationTrackingState({
    this.isTracking = false,
    this.isLoading = false,
    this.activeBookingId,
    this.lastLocation,
    this.error,
  });

  LocationTrackingState copyWith({
    bool? isTracking,
    bool? isLoading,
    String? activeBookingId,
    DriverLocationData? lastLocation,
    String? error,
    bool clearError = false,
    bool clearBooking = false,
    bool clearLocation = false,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isLoading: isLoading ?? this.isLoading,
      activeBookingId: clearBooking ? null : (activeBookingId ?? this.activeBookingId),
      lastLocation: clearLocation ? null : (lastLocation ?? this.lastLocation),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================
// TRACKING NOTIFIER (FOR DRIVER SIDE)
// ============================================

/// Notifier for managing driver's location tracking
class LocationTrackingNotifier extends StateNotifier<LocationTrackingState> {
  final LiveLocationService _service;

  LocationTrackingNotifier(this._service) : super(const LocationTrackingState());

  /// Start tracking location for a trip
  Future<bool> startTracking({
    required String bookingId,
    required String driverId,
  }) async {
    if (state.isTracking) {
      AppLogger.warning('Already tracking location', tag: 'LocationTracking');
      return true;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await _service.startTracking(
        bookingId: bookingId,
        driverId: driverId,
      );

      if (success) {
        state = state.copyWith(
          isTracking: true,
          isLoading: false,
          activeBookingId: bookingId,
        );
        AppLogger.success('Started tracking for booking: $bookingId', tag: 'LocationTracking');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to start location tracking. Please check permissions.',
        );
        return false;
      }
    } catch (e) {
      AppLogger.error('Error starting tracking', error: e, tag: 'LocationTracking');
      state = state.copyWith(
        isLoading: false,
        error: 'Error starting location tracking',
      );
      return false;
    }
  }

  /// Stop tracking location
  Future<void> stopTracking() async {
    if (!state.isTracking) return;

    state = state.copyWith(isLoading: true);

    try {
      await _service.stopTracking();
      state = state.copyWith(
        isTracking: false,
        isLoading: false,
        clearBooking: true,
        clearLocation: true,
      );
      AppLogger.success('Stopped tracking', tag: 'LocationTracking');
    } catch (e) {
      AppLogger.error('Error stopping tracking', error: e, tag: 'LocationTracking');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Check location permission status
  Future<bool> checkPermission() async {
    return _service.checkLocationPermission();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _service.stopTracking();
    super.dispose();
  }
}

// ============================================
// PROVIDERS
// ============================================

/// Provider for location tracking state (driver side)
final locationTrackingProvider =
    StateNotifierProvider<LocationTrackingNotifier, LocationTrackingState>((ref) {
  final service = ref.watch(liveLocationServiceProvider);
  return LocationTrackingNotifier(service);
});

/// Stream provider for driver location (user/rider side).
/// Pass the driverId (booking.driver.driverId) — reads from drivers/{driverId}.
final driverLocationStreamProvider =
    StreamProvider.family<DriverLocationData?, String>((ref, driverId) {
  final service = ref.watch(liveLocationServiceProvider);
  return service.getDriverLocationStream(driverId);
});

/// Future provider to get driver location once.
/// Pass the driverId (booking.driver.driverId).
final driverLocationProvider =
    FutureProvider.family<DriverLocationData?, String>((ref, driverId) async {
  final service = ref.watch(liveLocationServiceProvider);
  return service.getDriverLocation(driverId);
});

/// Provider to check if location permission is granted
final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(liveLocationServiceProvider);
  return service.checkLocationPermission();
});
