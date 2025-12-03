import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveBooking {
  final String bookingId;
  final String userId;
  final String vehicleType;
  final String status;
  final String driverName;
  final String? driverPhone;
  final String? driverImageUrl;
  final String eta;
  final DateTime createdAt;
  final String? pickupLocation;
  final String? dropLocation;

  ActiveBooking({
    required this.bookingId,
    required this.userId,
    required this.vehicleType,
    required this.status,
    required this.driverName,
    this.driverPhone,
    this.driverImageUrl,
    required this.eta,
    required this.createdAt,
    this.pickupLocation,
    this.dropLocation,
  });

  factory ActiveBooking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActiveBooking(
      bookingId: doc.id,
      userId: data['userId'] ?? '',
      vehicleType: data['vehicleType'] ?? 'Unknown',
      status: data['status'] ?? 'pending',
      driverName: data['driverName'] ?? 'Assigning...',
      driverPhone: data['driverPhone'],
      driverImageUrl: data['driverImageUrl'],
      eta: data['eta'] ?? 'Calculating...',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pickupLocation: data['pickupLocation'],
      dropLocation: data['dropLocation'],
    );
  }
}

class BookingModel {
  final String bookingId;
  final String userId;
  final String vehicleType;
  final String status;
  final DateTime createdAt;
  final double? fare;

  BookingModel({
    required this.bookingId,
    required this.userId,
    required this.vehicleType,
    required this.status,
    required this.createdAt,
    this.fare,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      bookingId: doc.id,
      userId: data['userId'] ?? '',
      vehicleType: data['vehicleType'] ?? 'Unknown',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fare: (data['fare'] as num?)?.toDouble(),
    );
  }
}
