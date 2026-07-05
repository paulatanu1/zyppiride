import 'package:cloud_firestore/cloud_firestore.dart';

class PointsEntry {
  final String id;
  final String title;
  final String? subtitle;
  final int delta;
  final DateTime? createdAt;

  PointsEntry({
    required this.id,
    required this.title,
    this.subtitle,
    required this.delta,
    this.createdAt,
  });

  factory PointsEntry.fromJson(Map<String, dynamic> json, {required String id}) {
    return PointsEntry(
      id: id,
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      delta: _asInt(json['delta']) ?? _asInt(json['points']) ?? 0,
      createdAt: _asDate(json['createdAt']),
    );
  }

  bool get isCredit => delta >= 0;

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
