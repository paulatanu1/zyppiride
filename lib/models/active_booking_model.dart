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
      bookingTime: json['bookingTime'] != null
          ? DateTime.parse(json['bookingTime'])
          : DateTime.now(),
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
}
