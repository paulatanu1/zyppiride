import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a driver's real-time location during a trip
class DriverLocationData {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime updatedAt;
  final String? bookingId;

  const DriverLocationData({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    required this.updatedAt,
    this.bookingId,
  });

  /// Create from Firestore document
  factory DriverLocationData.fromFirestore(Map<String, dynamic> data) {
    return DriverLocationData(
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (data['heading'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      // drivers doc uses 'lastUpdated'; fall back to 'updatedAt' for old data
      updatedAt: ((data['lastUpdated'] ?? data['updatedAt']) as Timestamp?)?.toDate() ?? DateTime.now(),
      bookingId: (data['currentBookingId'] ?? data['bookingId']) as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
      if (bookingId != null) 'bookingId': bookingId,
    };
  }

  /// Create a copy with updated values
  DriverLocationData copyWith({
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? updatedAt,
    String? bookingId,
  }) {
    return DriverLocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      updatedAt: updatedAt ?? this.updatedAt,
      bookingId: bookingId ?? this.bookingId,
    );
  }

  /// Check if location data is stale (older than 30 seconds)
  bool get isStale {
    return DateTime.now().difference(updatedAt).inSeconds > 30;
  }

  /// Get formatted speed in km/h
  String get formattedSpeed {
    if (speed == null || speed! < 0) return '--';
    return '${speed!.toStringAsFixed(0)} km/h';
  }

  /// Check if driver is moving
  bool get isMoving {
    return speed != null && speed! > 2.0; // Moving if > 2 km/h
  }

  @override
  String toString() {
    return 'DriverLocationData(lat: $latitude, lng: $longitude, heading: $heading, speed: $speed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriverLocationData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, updatedAt);
}

/// Extension for GeoPoint conversion
extension DriverLocationGeoPoint on DriverLocationData {
  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);

  static DriverLocationData fromGeoPoint(GeoPoint point) {
    return DriverLocationData(
      latitude: point.latitude,
      longitude: point.longitude,
      updatedAt: DateTime.now(),
    );
  }
}
