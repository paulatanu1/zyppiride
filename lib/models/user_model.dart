class UserModel {
  final String userId;
  final String userName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final int notificationCount;

  UserModel({
    required this.userId,
    required this.userName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.notificationCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      // Check for 'fullName' first (Firestore field), then 'userName', then default to 'User'
      userName: json['fullName'] ?? json['userName'] ?? 'User',
      email: json['email'],
      phoneNumber: json['phoneNumber'] ?? json['mobile'],
      profileImageUrl: json['profileImageUrl'],
      notificationCount: json['notificationCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'notificationCount': notificationCount,
    };
  }

  UserModel copyWith({
    String? userId,
    String? userName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    int? notificationCount,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      notificationCount: notificationCount ?? this.notificationCount,
    );
  }
}
