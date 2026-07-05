import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_logger.dart';
import '../services/location_service.dart';

// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Location state
class LocationState {
  final LocationData? location;
  final bool isLoading;
  final String? error;
  final LocationPermissionStatus? permissionStatus;

  LocationState({
    this.location,
    this.isLoading = false,
    this.error,
    this.permissionStatus,
  });

  LocationState copyWith({
    LocationData? location,
    bool? isLoading,
    String? error,
    LocationPermissionStatus? permissionStatus,
  }) {
    return LocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }

  bool get hasLocation => location != null;
  bool get isPermissionDenied =>
      permissionStatus == LocationPermissionStatus.denied ||
      permissionStatus == LocationPermissionStatus.deniedForever;
}

// Location state notifier
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _service;
  static const String _cacheKey = 'user_location_cache';

  LocationNotifier(this._service) : super(LocationState()) {
    _loadCachedLocation();
  }

  // Load cached location on init
  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson != null) {
        final data = json.decode(cachedJson) as Map<String, dynamic>;
        final location = LocationData.fromJson(data);
        state = state.copyWith(location: location);
        AppLogger.info('Loaded cached location: ${location.shortAddress}');
      }
    } catch (e) {
      AppLogger.warning('Failed to load cached location: $e');
    }
  }

  // Save location to cache
  Future<void> _cacheLocation(LocationData location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(location.toJson()));
      AppLogger.debug('Location cached');
    } catch (e) {
      AppLogger.warning('Failed to cache location: $e');
    }
  }

  // Get current location
  Future<void> getCurrentLocation() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _service.getCurrentLocation();

    result.when(
      success: (location) {
        state = state.copyWith(
          location: location,
          isLoading: false,
          permissionStatus: LocationPermissionStatus.granted,
        );
        _cacheLocation(location);
      },
      failure: (exception) {
        // Check if it's a permission error
        if (exception.message.contains('permission')) {
          state = state.copyWith(
            isLoading: false,
            error: exception.message,
            permissionStatus: exception.message.contains('permanently')
                ? LocationPermissionStatus.deniedForever
                : LocationPermissionStatus.denied,
          );
        } else if (exception.message.contains('disabled')) {
          state = state.copyWith(
            isLoading: false,
            error: exception.message,
            permissionStatus: LocationPermissionStatus.serviceDisabled,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: exception.message,
          );
        }
      },
    );
  }

  // Set location from address search
  Future<void> setLocationFromAddress(String address) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _service.getLocationFromAddress(address);

    result.when(
      success: (location) {
        state = state.copyWith(
          location: location,
          isLoading: false,
        );
        _cacheLocation(location);
      },
      failure: (exception) {
        state = state.copyWith(
          isLoading: false,
          error: exception.message,
        );
      },
    );
  }

  // Set location manually (from Google Places selection)
  void setLocation(LocationData location) {
    state = state.copyWith(location: location);
    _cacheLocation(location);
  }

  // Open settings
  Future<void> openLocationSettings() async {
    await _service.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _service.openAppSettings();
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Main location provider
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationNotifier(service);
});

// Convenience provider for just the location data
final currentLocationProvider = Provider<LocationData?>((ref) {
  return ref.watch(locationProvider).location;
});

// Provider for location loading state
final isLocationLoadingProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).isLoading;
});
