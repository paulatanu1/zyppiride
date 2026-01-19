import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String userName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final int notificationCount;
  final int totalRides;
  final double rating;
  final DateTime? createdAt;
  final String? role;

  UserModel({
    required this.userId,
    required this.userName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.notificationCount = 0,
    this.totalRides = 0,
    this.rating = 5.0,
    this.createdAt,
    this.role,
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
      totalRides: _parseIntSafe(json['totalRides'], 0),
      rating: _parseDoubleSafe(json['rating'], 5.0),
      createdAt: _parseDateTime(json['createdAt']),
      role: json['role'],
    );
  }

  static int _parseIntSafe(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _parseDoubleSafe(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
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
    );
  }

  /// Check if user is a driver/owner
  bool get isDriver => role == 'driver' || role == 'owner';

  /// Check if user is a regular user
  bool get isUser => role == 'user' || role == null;
}
