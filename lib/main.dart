import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/notification_provider.dart';
import 'router/router.dart';
import 'services/notification_service.dart';

/// Global scaffold messenger key — use this for all app-wide snackbars so they
/// survive route transitions and never hit "deactivated widget" assertion errors.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All screens are designed portrait-only; lock before the first frame.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    await Firebase.initializeApp();
  } catch (e) {
    runApp(_FirebaseErrorApp(error: e.toString()));
    return;
  }

  // Crashlytics: only in release. Debug crashes belong in the console.
  if (kReleaseMode) {
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Analytics: enable collection so events flow to the Firebase console.
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // Initialize Firebase App Check with Play Integrity (Android) / Device Check (iOS).
  // Use debug provider for debug AND profile builds; Play Integrity only for release.
  // kDebugMode is false in profile mode, so we check kReleaseMode instead.
  await FirebaseAppCheck.instance.activate(
    // ignore: deprecated_member_use
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
    // ignore: deprecated_member_use
    appleProvider: kReleaseMode
        ? AppleProvider.appAttest
        : AppleProvider.debug,
  );

  // DIAGNOSTIC: verify App Check token is valid — remove once confirmed working
  if (!kReleaseMode) {
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      debugPrint('[AppCheck] Token obtained: ${token != null ? 'OK (${token.length} chars)' : 'null'}');
    } catch (e) {
      debugPrint('[AppCheck] *** TOKEN FAILED: $e ***');
    }
  }

  // Setup FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Limit Firestore cache to 100MB to prevent excessive storage usage
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zyppi Ride',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16),
          labelLarge: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600),
        ),
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
    );
  }
}

/// Shown only when Firebase fails to initialise (e.g. no internet on cold start,
/// corrupted google-services.json, or missing SHA certificate in Firebase Console).
class _FirebaseErrorApp extends StatelessWidget {
  final String error;
  const _FirebaseErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.deepPurple,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Colors.white54),
                  const SizedBox(height: 24),
                  const Text(
                    'Could not connect',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please check your internet connection and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 20),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}