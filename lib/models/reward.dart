import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  final String id;
  final String title;
  final String? description;
  final int pointsCost;
  final String? imageUrl;
  final DateTime? expiryDate;
  final bool isActive;

  Reward({
    required this.id,
    required this.title,
    this.description,
    required this.pointsCost,
    this.imageUrl,
    this.expiryDate,
    this.isActive = true,
  });

  factory Reward.fromJson(Map<String, dynamic> json, {required String id}) {
    return Reward(
      id: id,
      title: json['title'] ?? '',
      description: json['description'],
      pointsCost: _asInt(json['pointsCost']) ?? 0,
      imageUrl: json['imageUrl'],
      expiryDate: _asDate(json['expiryDate']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
