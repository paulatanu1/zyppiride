import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for address labels/types
enum AddressLabel {
  home,
  work,
  other;

  String get displayName {
    switch (this) {
      case AddressLabel.home:
        return 'Home';
      case AddressLabel.work:
        return 'Work';
      case AddressLabel.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case AddressLabel.home:
        return '🏠';
      case AddressLabel.work:
        return '💼';
      case AddressLabel.other:
        return '📍';
    }
  }

  static AddressLabel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'home':
        return AddressLabel.home;
      case 'work':
        return AddressLabel.work;
      default:
        return AddressLabel.other;
    }
  }
}

/// Model for saved/frequently used addresses
class SavedAddress {
  final String addressId;
  final String userId;
  final AddressLabel label;
  final String? customLabel; // For 'other' type addresses
  final String address; // Full address string
  final String? area;
  final String? city;
  final String? state;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SavedAddress({
    required this.addressId,
    required this.userId,
    required this.label,
    this.customLabel,
    required this.address,
    this.area,
    this.city,
    this.state,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get display label (custom label for 'other', otherwise enum displayName)
  String get displayLabel {
    if (label == AddressLabel.other && customLabel != null && customLabel!.isNotEmpty) {
      return customLabel!;
    }
    return label.displayName;
  }

  /// Get short address (area + city)
  String get shortAddress {
    final parts = <String>[];
    if (area != null && area!.isNotEmpty) parts.add(area!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.isNotEmpty ? parts.join(', ') : address;
  }

  /// Get city and state
  String get cityState {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    return parts.join(', ');
  }

  /// Create from Firestore document
  factory SavedAddress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedAddress.fromMap(data, doc.id);
  }

  /// Create from Map with document ID
  factory SavedAddress.fromMap(Map<String, dynamic> map, String docId) {
    return SavedAddress(
      addressId: docId,
      userId: map['userId'] ?? '',
      label: AddressLabel.fromString(map['label'] ?? 'other'),
      customLabel: map['customLabel'],
      address: map['address'] ?? '',
      area: map['area'],
      city: map['city'],
      state: map['state'],
      postalCode: map['postalCode'],
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      isDefault: map['isDefault'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'label': label.name,
      'customLabel': customLabel,
      'address': address,
      'area': area,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create a copy with updated fields
  SavedAddress copyWith({
    String? addressId,
    String? userId,
    AddressLabel? label,
    String? customLabel,
    String? address,
    String? area,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedAddress(
      addressId: addressId ?? this.addressId,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      customLabel: customLabel ?? this.customLabel,
      address: address ?? this.address,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if coordinates are valid
  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;

  @override
  String toString() {
    return 'SavedAddress(addressId: $addressId, label: $displayLabel, address: $shortAddress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedAddress && other.addressId == addressId;
  }

  @override
  int get hashCode => addressId.hashCode;
}
