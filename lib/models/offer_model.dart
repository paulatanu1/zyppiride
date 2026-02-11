class OfferData {
  final String discount;
  final String title;
  final String description;
  final String code;

  OfferData({
    required this.discount,
    required this.title,
    required this.description,
    required this.code,
  });

  factory OfferData.fromJson(Map<String, dynamic> json) {
    return OfferData(
      discount: json['discount'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'discount': discount,
      'title': title,
      'description': description,
      'code': code,
    };
  }

  OfferData copyWith({
    String? discount,
    String? title,
    String? description,
    String? code,
  }) {
    return OfferData(
      discount: discount ?? this.discount,
      title: title ?? this.title,
      description: description ?? this.description,
      code: code ?? this.code,
    );
  }
}
