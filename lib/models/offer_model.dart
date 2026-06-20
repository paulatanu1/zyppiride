class OfferData {
  final String discount;
  final String title;
  final String description;
  final String code;
  final String minOrder;
  final String validTill;
  final bool isUsed;

  OfferData({
    required this.discount,
    required this.title,
    required this.description,
    required this.code,
    this.minOrder = '',
    this.validTill = '',
    this.isUsed = false,
  });

  factory OfferData.fromJson(Map<String, dynamic> json) {
    return OfferData(
      discount:    json['discount']    ?? '',
      title:       json['title']       ?? '',
      description: json['description'] ?? '',
      code:        json['code']        ?? '',
      minOrder:    json['minOrder']    ?? '',
      validTill:   json['validTill']   ?? '',
      isUsed:      json['isUsed']      as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'discount':    discount,
      'title':       title,
      'description': description,
      'code':        code,
      'minOrder':    minOrder,
      'validTill':   validTill,
      'isUsed':      isUsed,
    };
  }

  OfferData copyWith({
    String? discount,
    String? title,
    String? description,
    String? code,
    String? minOrder,
    String? validTill,
    bool?   isUsed,
  }) {
    return OfferData(
      discount:    discount    ?? this.discount,
      title:       title       ?? this.title,
      description: description ?? this.description,
      code:        code        ?? this.code,
      minOrder:    minOrder    ?? this.minOrder,
      validTill:   validTill   ?? this.validTill,
      isUsed:      isUsed      ?? this.isUsed,
    );
  }
}
