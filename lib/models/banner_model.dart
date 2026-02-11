class BannerData {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? actionRoute;

  BannerData({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.actionRoute,
  });

  factory BannerData.fromJson(Map<String, dynamic> json) {
    return BannerData(
      imageUrl: json['imageUrl'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      actionRoute: json['actionRoute'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'actionRoute': actionRoute,
    };
  }

  BannerData copyWith({
    String? imageUrl,
    String? title,
    String? subtitle,
    String? actionRoute,
  }) {
    return BannerData(
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }
}
