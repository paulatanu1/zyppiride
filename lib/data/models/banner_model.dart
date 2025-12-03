import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String bannerId;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? actionRoute;
  final int order;
  final bool isActive;

  BannerModel({
    required this.bannerId,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.actionRoute,
    required this.order,
    this.isActive = true,
  });

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BannerModel(
      bannerId: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      actionRoute: data['actionRoute'],
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }
}
