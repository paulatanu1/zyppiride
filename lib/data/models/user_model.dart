import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String userName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final int notificationCount;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.userId,
    required this.userName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.notificationCount = 0,
    this.role = 'user',
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: doc.id,
      userName: data['userName'] ?? data['name'] ?? 'User',
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      notificationCount: data['notificationCount'] ?? 0,
      role: data['role'] ?? 'user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'notificationCount': notificationCount,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
    };
  }

  UserModel copyWith({
    String? userName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    int? notificationCount,
    String? role,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      userId: userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      notificationCount: notificationCount ?? this.notificationCount,
      role: role ?? this.role,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
