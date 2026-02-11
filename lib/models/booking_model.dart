import 'package:cloud_firestore/cloud_firestore.dart';

/// Booking status enum with all possible states
enum BookingStatus {
  pending,      // Initial state when user creates booking
  confirmed,    // Driver accepted the booking
  driverArriving, // Driver is on the way to pickup
  arrived,      // Driver arrived at pickup location
  inProgress,   // Trip is ongoing
  completed,    // Trip completed successfully
  cancelled,    // Booking was cancelled
  rejected,     // Driver rejected the booking
  expired;      // Booking expired (no driver accepted)

  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.driverArriving:
        return 'Driver Arriving';
      case BookingStatus.arrived:
        return 'Driver Arrived';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.expired:
        return 'Expired';
    }
  }

  bool get isActive => this == BookingStatus.pending ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.driverArriving ||
      this == BookingStatus.arrived ||
      this == BookingStatus.inProgress;

  bool get isTerminal => this == BookingStatus.completed ||
      this == BookingStatus.cancelled ||
      this == BookingStatus.rejected ||
      this == BookingStatus.expired;

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BookingStatus.pending,
    );
  }
}

/// Booking type enum
enum BookingType {
  local,        // Local transport within city
  outstation,   // Long distance travel
  rental,       // Hourly/daily rental
  goods;        // Goods carrier

  String get displayName {
    switch (this) {
      case BookingType.local:
        return 'Local Transport';
      case BookingType.outstation:
        return 'Outstation';
      case BookingType.rental:
        return 'Vehicle Rental';
      case BookingType.goods:
        return 'Goods Carrier';
    }
  }

  static BookingType fromString(String value) {
    return BookingType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BookingType.local,
    );
  }
}

/// Payment status enum
enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
  partialRefund;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.completed:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partialRefund:
        return 'Partial Refund';
    }
  }

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Payment method enum
enum PaymentMethod {
  cash,
  upi,
  card,
  wallet,
  netBanking;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.wallet:
        return 'Wallet';
      case PaymentMethod.netBanking:
        return 'Net Banking';
    }
  }

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Location details for pickup/drop
class BookingLocation {
  final String address;
  final String? area;
  final String? city;
  final String? state;
  final double latitude;
  final double longitude;

  const BookingLocation({
    required this.address,
    this.area,
    this.city,
    this.state,
    required this.latitude,
    required this.longitude,
  });

  factory BookingLocation.fromMap(Map<String, dynamic> map) {
    return BookingLocation(
      address: map['address']?.toString() ?? '',
      area: map['area']?.toString(),
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      latitude: _parseDouble(map['latitude'], 0.0),
      longitude: _parseDouble(map['longitude'], 0.0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'area': area,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get shortAddress {
    if (area != null && area!.isNotEmpty) {
      return '$area, ${city ?? ''}';
    }
    return city ?? address;
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  BookingLocation copyWith({
    String? address,
    String? area,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
  }) {
    return BookingLocation(
      address: address ?? this.address,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// Fare breakdown details
class FareDetails {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double waitingCharges;
  final double tollCharges;
  final double gstAmount;
  final double discount;
  final double totalFare;
  final String? promoCode;
  final double? promoDiscount;

  const FareDetails({
    required this.baseFare,
    required this.distanceFare,
    this.timeFare = 0,
    this.waitingCharges = 0,
    this.tollCharges = 0,
    this.gstAmount = 0,
    this.discount = 0,
    required this.totalFare,
    this.promoCode,
    this.promoDiscount,
  });

  factory FareDetails.fromMap(Map<String, dynamic> map) {
    return FareDetails(
      baseFare: _parseDouble(map['baseFare'], 0),
      distanceFare: _parseDouble(map['distanceFare'], 0),
      timeFare: _parseDouble(map['timeFare'], 0),
      waitingCharges: _parseDouble(map['waitingCharges'], 0),
      tollCharges: _parseDouble(map['tollCharges'], 0),
      gstAmount: _parseDouble(map['gstAmount'], 0),
      discount: _parseDouble(map['discount'], 0),
      totalFare: _parseDouble(map['totalFare'], 0),
      promoCode: map['promoCode']?.toString(),
      promoDiscount: map['promoDiscount'] != null
          ? _parseDouble(map['promoDiscount'], 0)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'distanceFare': distanceFare,
      'timeFare': timeFare,
      'waitingCharges': waitingCharges,
      'tollCharges': tollCharges,
      'gstAmount': gstAmount,
      'discount': discount,
      'totalFare': totalFare,
      'promoCode': promoCode,
      'promoDiscount': promoDiscount,
    };
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Calculate fare from distance and pricing
  factory FareDetails.calculate({
    required double baseFare,
    required double perKmRate,
    required double distanceKm,
    double perMinuteRate = 0,
    int durationMinutes = 0,
    double waitingMinutes = 0,
    double waitingPerMinute = 2,
    double tollCharges = 0,
    double gstPercent = 5,
    double discount = 0,
    String? promoCode,
    double? promoDiscount,
  }) {
    final distanceFare = distanceKm * perKmRate;
    final timeFare = durationMinutes * perMinuteRate;
    final waitingCharges = waitingMinutes * waitingPerMinute;

    final subtotal = baseFare + distanceFare + timeFare + waitingCharges + tollCharges;
    final gstAmount = (subtotal * gstPercent) / 100;
    final totalDiscount = discount + (promoDiscount ?? 0);
    final totalFare = subtotal + gstAmount - totalDiscount;

    return FareDetails(
      baseFare: baseFare,
      distanceFare: distanceFare,
      timeFare: timeFare,
      waitingCharges: waitingCharges,
      tollCharges: tollCharges,
      gstAmount: gstAmount,
      discount: totalDiscount,
      totalFare: totalFare > 0 ? totalFare : 0,
      promoCode: promoCode,
      promoDiscount: promoDiscount,
    );
  }

  FareDetails copyWith({
    double? baseFare,
    double? distanceFare,
    double? timeFare,
    double? waitingCharges,
    double? tollCharges,
    double? gstAmount,
    double? discount,
    double? totalFare,
    String? promoCode,
    double? promoDiscount,
  }) {
    return FareDetails(
      baseFare: baseFare ?? this.baseFare,
      distanceFare: distanceFare ?? this.distanceFare,
      timeFare: timeFare ?? this.timeFare,
      waitingCharges: waitingCharges ?? this.waitingCharges,
      tollCharges: tollCharges ?? this.tollCharges,
      gstAmount: gstAmount ?? this.gstAmount,
      discount: discount ?? this.discount,
      totalFare: totalFare ?? this.totalFare,
      promoCode: promoCode ?? this.promoCode,
      promoDiscount: promoDiscount ?? this.promoDiscount,
    );
  }
}

/// Vehicle details snapshot at booking time
class BookingVehicleDetails {
  final String vehicleId;
  final String type;
  final String brand;
  final String model;
  final String registrationNumber;
  final String color;
  final int seatingCapacity;
  final bool hasAC;
  final String? imageUrl;

  const BookingVehicleDetails({
    required this.vehicleId,
    required this.type,
    required this.brand,
    required this.model,
    required this.registrationNumber,
    required this.color,
    required this.seatingCapacity,
    required this.hasAC,
    this.imageUrl,
  });

  factory BookingVehicleDetails.fromMap(Map<String, dynamic> map) {
    return BookingVehicleDetails(
      vehicleId: map['vehicleId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'car',
      brand: map['brand']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      registrationNumber: map['registrationNumber']?.toString() ?? '',
      color: map['color']?.toString() ?? '',
      seatingCapacity: _parseInt(map['seatingCapacity'], 4),
      hasAC: map['hasAC'] == true,
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'type': type,
      'brand': brand,
      'model': model,
      'registrationNumber': registrationNumber,
      'color': color,
      'seatingCapacity': seatingCapacity,
      'hasAC': hasAC,
      'imageUrl': imageUrl,
    };
  }

  String get displayName => '$brand $model';

  static int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}

/// Driver details snapshot at booking time
class BookingDriverDetails {
  final String driverId;
  final String name;
  final String? phoneNumber;
  final String? photoUrl;
  final double rating;
  final int totalTrips;

  const BookingDriverDetails({
    required this.driverId,
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    required this.rating,
    required this.totalTrips,
  });

  factory BookingDriverDetails.fromMap(Map<String, dynamic> map) {
    return BookingDriverDetails(
      driverId: map['driverId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Driver',
      phoneNumber: map['phoneNumber']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      rating: _parseDouble(map['rating'], 4.5),
      totalTrips: _parseInt(map['totalTrips'], 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'rating': rating,
      'totalTrips': totalTrips,
    };
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}

/// Main Booking Model
class Booking {
  final String bookingId;
  final String userId;
  final String userPhone;
  final String userName;

  // Booking type and status
  final BookingType bookingType;
  final BookingStatus status;

  // Location details
  final BookingLocation pickupLocation;
  final BookingLocation dropLocation;
  final List<BookingLocation>? stops; // For multi-stop trips

  // Trip details
  final double? estimatedDistance; // in km
  final int? estimatedDuration; // in minutes
  final String? estimatedArrival;

  // Vehicle and driver
  final BookingVehicleDetails vehicle;
  final BookingDriverDetails driver;

  // Fare and payment
  final FareDetails fareDetails;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentTransactionId;

  // Schedule (for pre-booked rides)
  final DateTime? scheduledAt;
  final bool isScheduled;

  // Timestamps
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime updatedAt;

  // Cancellation details
  final String? cancellationReason;
  final String? cancelledBy; // 'user' or 'driver'
  final double? cancellationFee;

  // Ratings (after completion)
  final double? userRating;
  final String? userReview;
  final double? driverRating;
  final String? driverReview;

  // OTP for ride verification
  final String? rideOtp;

  // Notes
  final String? userNotes;
  final String? driverNotes;

  const Booking({
    required this.bookingId,
    required this.userId,
    required this.userPhone,
    required this.userName,
    required this.bookingType,
    required this.status,
    required this.pickupLocation,
    required this.dropLocation,
    this.stops,
    this.estimatedDistance,
    this.estimatedDuration,
    this.estimatedArrival,
    required this.vehicle,
    required this.driver,
    required this.fareDetails,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentTransactionId,
    this.scheduledAt,
    this.isScheduled = false,
    required this.createdAt,
    this.confirmedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    required this.updatedAt,
    this.cancellationReason,
    this.cancelledBy,
    this.cancellationFee,
    this.userRating,
    this.userReview,
    this.driverRating,
    this.driverReview,
    this.rideOtp,
    this.userNotes,
    this.driverNotes,
  });

  /// Create from Firestore document
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking.fromMap(data, doc.id);
  }

  /// Create from Map with document ID
  factory Booking.fromMap(Map<String, dynamic> map, String docId) {
    return Booking(
      bookingId: docId,
      userId: map['userId']?.toString() ?? '',
      userPhone: map['userPhone']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      bookingType: BookingType.fromString(map['bookingType']?.toString() ?? 'local'),
      status: BookingStatus.fromString(map['status']?.toString() ?? 'pending'),
      pickupLocation: BookingLocation.fromMap(
        map['pickupLocation'] as Map<String, dynamic>? ?? {},
      ),
      dropLocation: BookingLocation.fromMap(
        map['dropLocation'] as Map<String, dynamic>? ?? {},
      ),
      stops: (map['stops'] as List<dynamic>?)
          ?.map((s) => BookingLocation.fromMap(s as Map<String, dynamic>))
          .toList(),
      estimatedDistance: _parseDoubleNullable(map['estimatedDistance']),
      estimatedDuration: _parseIntNullable(map['estimatedDuration']),
      estimatedArrival: map['estimatedArrival']?.toString(),
      vehicle: BookingVehicleDetails.fromMap(
        map['vehicle'] as Map<String, dynamic>? ?? {},
      ),
      driver: BookingDriverDetails.fromMap(
        map['driver'] as Map<String, dynamic>? ?? {},
      ),
      fareDetails: FareDetails.fromMap(
        map['fareDetails'] as Map<String, dynamic>? ?? {},
      ),
      paymentMethod: PaymentMethod.fromString(
        map['paymentMethod']?.toString() ?? 'cash',
      ),
      paymentStatus: PaymentStatus.fromString(
        map['paymentStatus']?.toString() ?? 'pending',
      ),
      paymentTransactionId: map['paymentTransactionId']?.toString(),
      scheduledAt: _parseDateTime(map['scheduledAt']),
      isScheduled: map['isScheduled'] == true,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      confirmedAt: _parseDateTime(map['confirmedAt']),
      startedAt: _parseDateTime(map['startedAt']),
      completedAt: _parseDateTime(map['completedAt']),
      cancelledAt: _parseDateTime(map['cancelledAt']),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      cancellationReason: map['cancellationReason']?.toString(),
      cancelledBy: map['cancelledBy']?.toString(),
      cancellationFee: _parseDoubleNullable(map['cancellationFee']),
      userRating: _parseDoubleNullable(map['userRating']),
      userReview: map['userReview']?.toString(),
      driverRating: _parseDoubleNullable(map['driverRating']),
      driverReview: map['driverReview']?.toString(),
      rideOtp: map['rideOtp']?.toString(),
      userNotes: map['userNotes']?.toString(),
      driverNotes: map['driverNotes']?.toString(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userPhone': userPhone,
      'userName': userName,
      'bookingType': bookingType.name,
      'status': status.name,
      'pickupLocation': pickupLocation.toMap(),
      'dropLocation': dropLocation.toMap(),
      'stops': stops?.map((s) => s.toMap()).toList(),
      'estimatedDistance': estimatedDistance,
      'estimatedDuration': estimatedDuration,
      'estimatedArrival': estimatedArrival,
      'vehicle': vehicle.toMap(),
      'driver': driver.toMap(),
      'fareDetails': fareDetails.toMap(),
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'paymentTransactionId': paymentTransactionId,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'isScheduled': isScheduled,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'cancellationFee': cancellationFee,
      'userRating': userRating,
      'userReview': userReview,
      'driverRating': driverRating,
      'driverReview': driverReview,
      'rideOtp': rideOtp,
      'userNotes': userNotes,
      'driverNotes': driverNotes,
    };
  }

  /// Parse helpers
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Getters for common checks
  bool get isPending => status == BookingStatus.pending;
  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isActive => status.isActive;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isCancelled => status == BookingStatus.cancelled;
  bool get canCancel => status == BookingStatus.pending || status == BookingStatus.confirmed;
  bool get canRate => status == BookingStatus.completed && userRating == null;
  bool get isPaid => paymentStatus == PaymentStatus.completed;

  /// Copy with
  Booking copyWith({
    String? bookingId,
    String? userId,
    String? userPhone,
    String? userName,
    BookingType? bookingType,
    BookingStatus? status,
    BookingLocation? pickupLocation,
    BookingLocation? dropLocation,
    List<BookingLocation>? stops,
    double? estimatedDistance,
    int? estimatedDuration,
    String? estimatedArrival,
    BookingVehicleDetails? vehicle,
    BookingDriverDetails? driver,
    FareDetails? fareDetails,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    String? paymentTransactionId,
    DateTime? scheduledAt,
    bool? isScheduled,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? updatedAt,
    String? cancellationReason,
    String? cancelledBy,
    double? cancellationFee,
    double? userRating,
    String? userReview,
    double? driverRating,
    String? driverReview,
    String? rideOtp,
    String? userNotes,
    String? driverNotes,
  }) {
    return Booking(
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      userPhone: userPhone ?? this.userPhone,
      userName: userName ?? this.userName,
      bookingType: bookingType ?? this.bookingType,
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      stops: stops ?? this.stops,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      vehicle: vehicle ?? this.vehicle,
      driver: driver ?? this.driver,
      fareDetails: fareDetails ?? this.fareDetails,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isScheduled: isScheduled ?? this.isScheduled,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      userRating: userRating ?? this.userRating,
      userReview: userReview ?? this.userReview,
      driverRating: driverRating ?? this.driverRating,
      driverReview: driverReview ?? this.driverReview,
      rideOtp: rideOtp ?? this.rideOtp,
      userNotes: userNotes ?? this.userNotes,
      driverNotes: driverNotes ?? this.driverNotes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Booking && other.bookingId == bookingId;
  }

  @override
  int get hashCode => bookingId.hashCode;

  @override
  String toString() {
    return 'Booking(id: $bookingId, status: ${status.name}, type: ${bookingType.name})';
  }
}

/// Request model for creating a new booking
class CreateBookingRequest {
  final String userId;
  final String userPhone;
  final String userName;
  final BookingType bookingType;
  final BookingLocation pickupLocation;
  final BookingLocation dropLocation;
  final List<BookingLocation>? stops;
  final String vehicleId;
  final String driverId;
  final double estimatedDistance;
  final int estimatedDuration;
  final PaymentMethod paymentMethod;
  final DateTime? scheduledAt;
  final String? promoCode;
  final String? userNotes;

  const CreateBookingRequest({
    required this.userId,
    required this.userPhone,
    required this.userName,
    required this.bookingType,
    required this.pickupLocation,
    required this.dropLocation,
    this.stops,
    required this.vehicleId,
    required this.driverId,
    required this.estimatedDistance,
    required this.estimatedDuration,
    required this.paymentMethod,
    this.scheduledAt,
    this.promoCode,
    this.userNotes,
  });

  bool get isScheduled => scheduledAt != null;
}
