import 'package:cloud_firestore/cloud_firestore.dart';

class OfferBannerData {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String discount;
  final String? promoCode;
  final String? actionRoute;
  final DateTime? expiryDate;
  final bool isActive;
  final int priority;

  OfferBannerData({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.discount,
    this.promoCode,
    this.actionRoute,
    this.expiryDate,
    this.isActive = true,
    this.priority = 0,
  });

  factory OfferBannerData.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime? expiry;
    if (json['expiryDate'] != null) {
      if (json['expiryDate'] is Timestamp) {
        expiry = (json['expiryDate'] as Timestamp).toDate();
      } else if (json['expiryDate'] is String) {
        expiry = DateTime.tryParse(json['expiryDate']);
      }
    }

    return OfferBannerData(
      id: docId ?? json['id'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      discount: json['discount'] ?? '',
      promoCode: json['promoCode'],
      actionRoute: json['actionRoute'],
      expiryDate: expiry,
      isActive: json['isActive'] ?? true,
      priority: json['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'discount': discount,
      'promoCode': promoCode,
      'actionRoute': actionRoute,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'priority': priority,
    };
  }

  OfferBannerData copyWith({
    String? id,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? discount,
    String? promoCode,
    String? actionRoute,
    DateTime? expiryDate,
    bool? isActive,
    int? priority,
  }) {
    return OfferBannerData(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      discount: discount ?? this.discount,
      promoCode: promoCode ?? this.promoCode,
      actionRoute: actionRoute ?? this.actionRoute,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
    );
  }
}
