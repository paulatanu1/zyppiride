import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String userName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final int notificationCount;
  final int? totalRides;
  final double? rating;
  final DateTime? createdAt;
  final String? role;

  // Rewards fields (nullable so UI can show '—' when unset)
  final int? totalPoints;
  final int? availableCoupons;
  final String? tier;
  final int? ridesToNextTier;
  final String? nextTier;

  // Verification fields
  final String? verificationStatus; // pending, submitted, approved, rejected
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationApprovedAt;
  final String? verificationNotes;

  // FCM fields
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;

  UserModel({
    required this.userId,
    required this.userName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.notificationCount = 0,
    this.totalRides,
    this.rating,
    this.createdAt,
    this.role,
    this.totalPoints,
    this.availableCoupons,
    this.tier,
    this.ridesToNextTier,
    this.nextTier,
    this.verificationStatus,
    this.verificationSubmittedAt,
    this.verificationApprovedAt,
    this.verificationNotes,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      // Check for 'fullName' first (Firestore field), then 'userName', then default to 'User'
      userName: json['fullName'] ?? json['userName'] ?? json['name'] ?? 'User',
      email: json['email'],
      phoneNumber: json['phoneNumber'] ?? json['mobile'],
      profileImageUrl: json['profileImageUrl'],
      notificationCount: _parseIntSafe(json['notificationCount'], 0),
      totalRides: _parseIntNullable(json['totalRides']),
      rating: _parseDoubleNullable(json['rating']),
      createdAt: _parseDateTime(json['createdAt']),
      role: json['role'],
      totalPoints: _parseIntNullable(json['totalPoints']),
      availableCoupons: _parseIntNullable(json['availableCoupons']),
      tier: json['tier'],
      ridesToNextTier: _parseIntNullable(json['ridesToNextTier']),
      nextTier: json['nextTier'],
      // Verification fields
      verificationStatus: json['verificationStatus'],
      verificationSubmittedAt: _parseDateTime(json['verificationSubmittedAt']),
      verificationApprovedAt: _parseDateTime(json['verificationApprovedAt']),
      verificationNotes: json['verificationNotes'],
      // FCM fields
      fcmToken: json['fcmToken'],
      fcmTokenUpdatedAt: _parseDateTime(json['fcmTokenUpdatedAt']),
    );
  }

  static int _parseIntSafe(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'notificationCount': notificationCount,
      'totalRides': totalRides,
      'rating': rating,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'role': role,
      'totalPoints': totalPoints,
      'availableCoupons': availableCoupons,
      'tier': tier,
      'ridesToNextTier': ridesToNextTier,
      'nextTier': nextTier,
      // Verification fields
      'verificationStatus': verificationStatus,
      'verificationSubmittedAt': verificationSubmittedAt != null
          ? Timestamp.fromDate(verificationSubmittedAt!)
          : null,
      'verificationApprovedAt': verificationApprovedAt != null
          ? Timestamp.fromDate(verificationApprovedAt!)
          : null,
      'verificationNotes': verificationNotes,
      // FCM fields
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null
          ? Timestamp.fromDate(fcmTokenUpdatedAt!)
          : null,
    };
  }

  UserModel copyWith({
    String? userId,
    String? userName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    int? notificationCount,
    int? totalRides,
    double? rating,
    DateTime? createdAt,
    String? role,
    String? verificationStatus,
    DateTime? verificationSubmittedAt,
    DateTime? verificationApprovedAt,
    String? verificationNotes,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    int? totalPoints,
    int? availableCoupons,
    String? tier,
    int? ridesToNextTier,
    String? nextTier,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      notificationCount: notificationCount ?? this.notificationCount,
      totalRides: totalRides ?? this.totalRides,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationSubmittedAt:
          verificationSubmittedAt ?? this.verificationSubmittedAt,
      verificationApprovedAt:
          verificationApprovedAt ?? this.verificationApprovedAt,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
      totalPoints: totalPoints ?? this.totalPoints,
      availableCoupons: availableCoupons ?? this.availableCoupons,
      tier: tier ?? this.tier,
      ridesToNextTier: ridesToNextTier ?? this.ridesToNextTier,
      nextTier: nextTier ?? this.nextTier,
    );
  }

  /// Check if user is a driver/owner
  bool get isDriver => role == 'driver' || role == 'owner' || role == 'Driver' || role == 'Vehicle Owner';

  /// Check if user is a regular user
  bool get isUser => role == 'user' || role == 'User' || role == null;

  /// Check if user is verified
  bool get isVerified => verificationStatus == 'approved';

  /// Check if user can go online (verified and is driver)
  bool get canGoOnline => isDriver && isVerified;

  /// Check if verification is pending
  bool get isVerificationPending =>
      verificationStatus == 'pending' || verificationStatus == 'submitted';

  /// Check if verification was rejected
  bool get isVerificationRejected => verificationStatus == 'rejected';
}
