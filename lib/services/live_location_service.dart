import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_location_model.dart';
import '../core/utils/app_logger.dart';

/// Service for managing real-time driver location tracking during trips
class LiveLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _updateTimer;
  String? _activeBookingId;
  String? _activeDriverId;

  /// Location update interval in seconds
  static const int updateIntervalSeconds = 5;

  /// Minimum distance change in meters to trigger update
  static const int distanceFilterMeters = 10;

  /// Check if location services are enabled and permissions granted
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.warning('Location services are disabled', tag: 'LiveLocation');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.warning('Location permission denied', tag: 'LiveLocation');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.error('Location permission permanently denied', tag: 'LiveLocation');
      return false;
    }

    return true;
  }

  /// Start tracking driver location for a booking
  Future<bool> startTracking({
    required String bookingId,
    required String driverId,
  }) async {
    AppLogger.info(
      'Starting location tracking for booking: $bookingId',
      tag: 'LiveLocation',
    );

    // Check permissions first
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      AppLogger.error('Cannot start tracking - no permission', tag: 'LiveLocation');
      return false;
    }

    // Stop any existing tracking
    await stopTracking();

    _activeBookingId = bookingId;
    _activeDriverId = driverId;

    try {
      // Get initial position
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        ),
      );

      // Save initial location
      await _updateLocation(initialPosition);

      // Start continuous location stream
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        ),
      ).listen(
        (Position position) {
          _updateLocation(position);
        },
        onError: (error) {
          AppLogger.error(
            'Location stream error',
            error: error,
            tag: 'LiveLocation',
          );
        },
      );

      // Also set up a timer for periodic updates (ensures updates even if device is stationary)
      _updateTimer = Timer.periodic(
        Duration(seconds: updateIntervalSeconds),
        (_) async {
          try {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            await _updateLocation(position);
          } catch (e) {
            AppLogger.error('Periodic update failed', error: e, tag: 'LiveLocation');
          }
        },
      );

      AppLogger.success('Location tracking started', tag: 'LiveLocation');
      return true;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to start location tracking',
        error: e,
        stackTrace: stack,
        tag: 'LiveLocation',
      );
      return false;
    }
  }

  /// Update driver location in Firestore
  Future<void> _updateLocation(Position position) async {
    if (_activeBookingId == null || _activeDriverId == null) return;

    try {
      final locationData = DriverLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed * 3.6, // Convert m/s to km/h
        accuracy: position.accuracy,
        updatedAt: DateTime.now(),
        bookingId: _activeBookingId,
      );

      // Update in booking document
      await _firestore.collection('bookings').doc(_activeBookingId).update({
        'driverLocation': locationData.toFirestore(),
      });

      // Also update driver's current location
      await _firestore.collection('drivers').doc(_activeDriverId).update({
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      AppLogger.debug(
        'Location updated: ${position.latitude}, ${position.longitude}',
        tag: 'LiveLocation',
      );
    } catch (e) {
      AppLogger.error('Failed to update location', error: e, tag: 'LiveLocation');
    }
  }

  /// Stop tracking driver location
  Future<void> stopTracking() async {
    AppLogger.info('Stopping location tracking', tag: 'LiveLocation');

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _updateTimer?.cancel();
    _updateTimer = null;

    // Clear location from booking if active
    if (_activeBookingId != null) {
      try {
        await _firestore.collection('bookings').doc(_activeBookingId).update({
          'driverLocation': FieldValue.delete(),
        });
      } catch (e) {
        AppLogger.warning(
          'Could not clear location from booking',
          tag: 'LiveLocation',
        );
      }
    }

    _activeBookingId = null;
    _activeDriverId = null;

    AppLogger.success('Location tracking stopped', tag: 'LiveLocation');
  }

  /// Get stream of driver location for a booking (for user/rider side)
  Stream<DriverLocationData?> getDriverLocationStream(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null || data['driverLocation'] == null) return null;

      return DriverLocationData.fromFirestore(
        data['driverLocation'] as Map<String, dynamic>,
      );
    });
  }

  /// Get current driver location (one-time fetch)
  Future<DriverLocationData?> getDriverLocation(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data['driverLocation'] == null) return null;

      return DriverLocationData.fromFirestore(
        data['driverLocation'] as Map<String, dynamic>,
      );
    } catch (e) {
      AppLogger.error('Failed to get driver location', error: e, tag: 'LiveLocation');
      return null;
    }
  }

  /// Check if tracking is currently active
  bool get isTracking => _locationSubscription != null;

  /// Get the active booking ID
  String? get activeBookingId => _activeBookingId;

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}
