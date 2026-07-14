import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info(
    'Background message received: ${message.messageId}',
    tag: 'FCM',
  );
}

/// Service for handling push notifications via Firebase Cloud Messaging
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'zyppi_ride_channel',
    'Zyppi Ride Notifications',
    description: 'Booking and ride notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // Callback for handling notification taps
  Function(Map<String, dynamic>)? onNotificationTap;

  /// Initialize FCM and request permissions
  Future<Result<String?>> initialize() async {
    try {
      AppLogger.info('Initializing FCM...', tag: 'NotificationService');

      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      AppLogger.info(
        'Notification permission: ${settings.authorizationStatus}',
        tag: 'NotificationService',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return Result.failure(
          ValidationException(message: 'Notification permission denied'),
        );
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        AppLogger.success('FCM Token obtained', tag: 'NotificationService');
        AppLogger.debug('Token: ${token.substring(0, 20)}...', tag: 'FCM');
      }

      // Setup message handlers
      _setupMessageHandlers();

      return Result.success(token);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'FCM initialize');
      return Result.failure(exception);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Android settings
    // Small icons must be alpha-only silhouettes; the monochrome launcher
    // asset (transparent background) renders as the Z mark, while the full
    // ic_launcher would show as a solid blob.
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_launcher_monochrome');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // Initialize
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    AppLogger.success(
      'Local notifications initialized',
      tag: 'NotificationService',
    );
  }

  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        AppLogger.info(
          'App opened from terminated state via notification',
          tag: 'NotificationService',
        );
        _handleNotificationTap(message);
      }
    });

    AppLogger.info('Message handlers setup complete', tag: 'NotificationService');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.info(
      'Foreground message: ${message.notification?.title}',
      tag: 'NotificationService',
    );

    // Show local notification
    await showLocalNotification(
      title: message.notification?.title ?? 'Zyppi Ride',
      body: message.notification?.body ?? '',
      payload: _encodePayload(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.userAction(
      'Notification tapped',
      details: {'type': message.data['type']},
    );

    // Call the callback if set
    onNotificationTap?.call(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.userAction('Local notification tapped');

    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      onNotificationTap?.call(data);
    }
  }

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (final part in payload.split('&')) {
      // Use indexOf so values containing '=' (URLs, base64, etc.) are preserved.
      final eqIndex = part.indexOf('=');
      if (eqIndex > 0) {
        map[part.substring(0, eqIndex)] = part.substring(eqIndex + 1);
      }
    }
    return map;
  }

  /// Show a local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'zyppi_ride_channel',
      'Zyppi Ride Notifications',
      channelDescription: 'Notifications for ride updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_monochrome',
      color: Color(0xFF673AB7),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  /// Store FCM token in user document
  Future<Result<void>> saveFcmToken(String userId, String token) async {
    try {
      // Use set with merge to create document if it doesn't exist
      await _firestore.collection(TestMode.usersCollection).doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.firestore('UPDATE', 'users', docId: '$userId (fcmToken)');
      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'saveFcmToken');
      return Result.failure(exception);
    }
  }

  /// Remove FCM token from user document (on logout)
  Future<Result<void>> removeFcmToken(String userId) async {
    try {
      // Check if document exists before trying to update
      final docRef = _firestore.collection(TestMode.usersCollection).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        await docRef.update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        });
        AppLogger.firestore('UPDATE', 'users', docId: '$userId (remove fcmToken)');
      }

      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      return Result.failure(exception);
    }
  }

  /// Listen for token refresh
  void onTokenRefresh(void Function(String) callback) {
    _messaging.onTokenRefresh.listen((newToken) {
      AppLogger.info('FCM token refreshed', tag: 'NotificationService');
      callback(newToken);
    });
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    AppLogger.info('Subscribed to topic: $topic', tag: 'NotificationService');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    AppLogger.info('Unsubscribed from topic: $topic', tag: 'NotificationService');
  }

  /// Subscribe to driver-specific topics
  Future<void> subscribeAsDriver(String userId) async {
    await subscribeToTopic('all_users');
    await subscribeToTopic('drivers');
    await subscribeToTopic('driver_$userId');
    AppLogger.success('Subscribed to driver topics', tag: 'NotificationService');
  }

  /// Unsubscribe from driver topics
  Future<void> unsubscribeAsDriver(String userId) async {
    await unsubscribeFromTopic('all_users');
    await unsubscribeFromTopic('drivers');
    await unsubscribeFromTopic('driver_$userId');
    AppLogger.info('Unsubscribed from driver topics', tag: 'NotificationService');
  }

  /// Subscribe to user-specific topics
  Future<void> subscribeAsUser(String userId) async {
    await subscribeToTopic('all_users');
    await subscribeToTopic('users');
    await subscribeToTopic('user_$userId');
    AppLogger.success('Subscribed to user topics', tag: 'NotificationService');
  }

  /// Unsubscribe from user topics
  Future<void> unsubscribeAsUser(String userId) async {
    await unsubscribeFromTopic('all_users');
    await unsubscribeFromTopic('users');
    await unsubscribeFromTopic('user_$userId');
    AppLogger.info('Unsubscribed from user topics', tag: 'NotificationService');
  }

  /// Request notification permission (for manual trigger)
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}
