import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants/test_mode.dart';
import '../core/utils/app_logger.dart';
import '../models/driver_location_model.dart';

/// Service for managing real-time driver location tracking during trips.
///
/// Canonical location store: drivers/{driverId} with flat fields
/// (latitude, longitude, heading, speed, lastUpdated, currentBookingId).
/// These match the Firestore security rules exactly.
class LiveLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _locationSubscription;
  String? _activeBookingId;
  String? _activeDriverId;

  static const int _distanceFilterMeters = 10;

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

  Future<bool> startTracking({
    required String bookingId,
    required String driverId,
  }) async {
    AppLogger.info('Starting location tracking for booking: $bookingId', tag: 'LiveLocation');

    final hasPermission = await checkLocationPermission();
    if (!hasPermission) return false;

    await stopTracking();

    _activeBookingId = bookingId;
    _activeDriverId = driverId;

    try {
      // Mark this booking as the driver's active trip
      await _firestore.collection(TestMode.driversCollection).doc(driverId).set({
        'currentBookingId': bookingId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Get initial position immediately
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _distanceFilterMeters,
        ),
      );
      await _writeLocation(initial);

      // Single adaptive stream — distanceFilter handles stationary periods
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _distanceFilterMeters,
        ),
      ).listen(
        _writeLocation,
        onError: (e) => AppLogger.error('Location stream error', error: e, tag: 'LiveLocation'),
      );

      AppLogger.success('Location tracking started', tag: 'LiveLocation');
      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to start location tracking', error: e, stackTrace: stack, tag: 'LiveLocation');
      _activeBookingId = null;
      _activeDriverId = null;
      return false;
    }
  }

  Future<void> _writeLocation(Position position) async {
    if (_activeDriverId == null) return;

    try {
      // Write flat fields to drivers/{driverId} — matches Firestore rules exactly.
      await _firestore.collection(TestMode.driversCollection).doc(_activeDriverId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed * 3.6, // m/s → km/h
        'lastUpdated': FieldValue.serverTimestamp(),
        'currentBookingId': _activeBookingId,
      });

      AppLogger.debug('Location: ${position.latitude}, ${position.longitude}', tag: 'LiveLocation');
    } catch (e) {
      AppLogger.error('Failed to write location', error: e, tag: 'LiveLocation');
    }
  }

  Future<void> stopTracking() async {
    AppLogger.info('Stopping location tracking', tag: 'LiveLocation');

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    // Clear the active booking reference from the driver document
    if (_activeDriverId != null) {
      try {
        await _firestore.collection(TestMode.driversCollection).doc(_activeDriverId).update({
          'currentBookingId': FieldValue.delete(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        AppLogger.warning('Could not clear driver booking reference', tag: 'LiveLocation');
      }
    }

    _activeBookingId = null;
    _activeDriverId = null;

    AppLogger.success('Location tracking stopped', tag: 'LiveLocation');
  }

  /// Stream driver location from the drivers collection (passenger/tracking side).
  /// Reads flat fields: latitude, longitude, heading, speed, lastUpdated.
  Stream<DriverLocationData?> getDriverLocationStream(String driverId) {
    return _firestore
        .collection(TestMode.driversCollection)
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null || data['latitude'] == null) return null;
      return DriverLocationData.fromFirestore(data);
    });
  }

  /// One-time fetch of driver location.
  Future<DriverLocationData?> getDriverLocation(String driverId) async {
    try {
      final doc = await _firestore
          .collection(TestMode.driversCollection)
          .doc(driverId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || data['latitude'] == null) return null;
      return DriverLocationData.fromFirestore(data);
    } catch (e) {
      AppLogger.error('Failed to get driver location', error: e, tag: 'LiveLocation');
      return null;
    }
  }

  bool get isTracking => _locationSubscription != null;
  String? get activeBookingId => _activeBookingId;

  void dispose() {
    stopTracking();
  }
}
