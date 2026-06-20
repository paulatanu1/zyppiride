import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String type; // 'ride' | 'offer' | 'system'
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.actionRoute,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      type: d['type']?.toString() ?? 'system',
      title: d['title']?.toString() ?? '',
      message: d['message']?.toString() ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: d['isRead'] == true,
      actionRoute: d['actionRoute']?.toString(),
    );
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        message: message,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        actionRoute: actionRoute,
      );
}
