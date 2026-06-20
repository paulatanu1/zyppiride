import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../core/utils/app_logger.dart';

// ── In-app notification history (Firestore) ───────────────────────────────────

/// Streams notification items for [userId] from Firestore, newest first.
/// Collection path: users/{userId}/notifications
final userNotificationsProvider =
    StreamProvider.family<List<NotificationItem>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(NotificationItem.fromFirestore).toList());
});

/// Marks a single notification as read in Firestore.
Future<void> markNotificationRead(String userId, String notifId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc(notifId)
      .update({'isRead': true});
}

/// Marks all unread notifications as read (batch write).
Future<void> markAllNotificationsRead(
    String userId, List<NotificationItem> items) async {
  final batch = FirebaseFirestore.instance.batch();
  for (final item in items.where((n) => !n.isRead)) {
    batch.update(
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(item.id),
      {'isRead': true},
    );
  }
  await batch.commit();
}

/// Deletes a notification document from Firestore.
Future<void> deleteNotification(String userId, String notifId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc(notifId)
      .delete();
}

// ─────────────────────────────────────────────────────────────────────────────

// Service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Notification state
class NotificationState {
  final bool isInitialized;
  final bool hasPermission;
  final String? fcmToken;
  final String? error;

  const NotificationState({
    this.isInitialized = false,
    this.hasPermission = false,
    this.fcmToken,
    this.error,
  });

  NotificationState copyWith({
    bool? isInitialized,
    bool? hasPermission,
    String? fcmToken,
    String? error,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      fcmToken: fcmToken ?? this.fcmToken,
      error: error,
    );
  }
}

// Notification notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;

  NotificationNotifier(this._service) : super(const NotificationState());

  /// Initialize notifications
  Future<void> initialize() async {
    if (state.isInitialized) return;

    AppLogger.info('Initializing notifications...', tag: 'NotificationNotifier');

    final result = await _service.initialize();

    result.when(
      success: (token) {
        state = state.copyWith(
          isInitialized: true,
          hasPermission: true,
          fcmToken: token,
        );

        // Save token for current user
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null && token != null) {
          _service.saveFcmToken(userId, token);
        }

        // Listen for token refresh
        _service.onTokenRefresh((newToken) {
          state = state.copyWith(fcmToken: newToken);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            _service.saveFcmToken(uid, newToken);
          }
        });

        AppLogger.success(
          'Notifications initialized successfully',
          tag: 'NotificationNotifier',
        );
      },
      failure: (exception) {
        state = state.copyWith(
          isInitialized: true,
          hasPermission: false,
          error: exception.message,
        );
        AppLogger.error(
          'Notification init failed: ${exception.message}',
          tag: 'NotificationNotifier',
        );
      },
    );
  }

  /// Set notification tap handler
  void setNotificationTapHandler(Function(Map<String, dynamic>) handler) {
    _service.onNotificationTap = handler;
  }

  /// Save token for user
  Future<void> saveTokenForUser(String userId) async {
    if (state.fcmToken != null) {
      await _service.saveFcmToken(userId, state.fcmToken!);
    }
  }

  /// Remove token on logout
  Future<void> removeTokenForUser(String userId) async {
    await _service.removeFcmToken(userId);
  }

  /// Subscribe to driver topics
  Future<void> subscribeAsDriver(String userId) async {
    await _service.subscribeAsDriver(userId);
  }

  /// Unsubscribe from driver topics
  Future<void> unsubscribeAsDriver(String userId) async {
    await _service.unsubscribeAsDriver(userId);
  }

  /// Subscribe to user topics
  Future<void> subscribeAsUser(String userId) async {
    await _service.subscribeAsUser(userId);
  }

  /// Unsubscribe from user topics
  Future<void> unsubscribeAsUser(String userId) async {
    await _service.unsubscribeAsUser(userId);
  }

  /// Show local notification manually
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _service.showLocalNotification(
      title: title,
      body: body,
      payload: data?.entries.map((e) => '${e.key}=${e.value}').join('&'),
    );
  }

  /// Request permission manually
  Future<bool> requestPermission() async {
    final granted = await _service.requestPermission();
    state = state.copyWith(hasPermission: granted);
    return granted;
  }
}

// Main provider
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationNotifier(service);
});

// Provider to check if notifications are enabled
final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.areNotificationsEnabled();
});
