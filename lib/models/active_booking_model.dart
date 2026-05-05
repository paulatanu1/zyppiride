import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveBooking {
  final String bookingId;
  final String userId;
  final String vehicleType;
  final String status;
  final String driverName;
  final String driverId;
  final String eta;
  final String pickupLocation;
  final String dropLocation;
  final double fare;
  final DateTime bookingTime;

  ActiveBooking({
    required this.bookingId,
    required this.userId,
    required this.vehicleType,
    required this.status,
    required this.driverName,
    required this.driverId,
    required this.eta,
    required this.pickupLocation,
    required this.dropLocation,
    required this.fare,
    required this.bookingTime,
  });

  factory ActiveBooking.fromJson(Map<String, dynamic> json) {
    return ActiveBooking(
      bookingId: json['bookingId'] ?? '',
      userId: json['userId'] ?? '',
      vehicleType: json['vehicleType'] ?? 'Unknown',
      status: json['status'] ?? 'pending',
      driverName: json['driverName'] ?? 'Driver',
      driverId: json['driverId'] ?? '',
      eta: json['eta'] ?? '10 mins',
      pickupLocation: json['pickupLocation'] ?? '',
      dropLocation: json['dropLocation'] ?? '',
      fare: (json['fare'] ?? 0).toDouble(),
      bookingTime: _parseDateTime(json['createdAt'] ?? json['bookingTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'vehicleType': vehicleType,
      'status': status,
      'driverName': driverName,
      'driverId': driverId,
      'eta': eta,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'fare': fare,
      'bookingTime': bookingTime.toIso8601String(),
    };
  }

  ActiveBooking copyWith({
    String? bookingId,
    String? userId,
    String? vehicleType,
    String? status,
    String? driverName,
    String? driverId,
    String? eta,
    String? pickupLocation,
    String? dropLocation,
    double? fare,
    DateTime? bookingTime,
  }) {
    return ActiveBooking(
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      eta: eta ?? this.eta,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      fare: fare ?? this.fare,
      bookingTime: bookingTime ?? this.bookingTime,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveBooking &&
          runtimeType == other.runtimeType &&
          bookingId == other.bookingId;

  @override
  int get hashCode => bookingId.hashCode;
}
