import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Limit Firestore cache to 100MB to prevent excessive storage usage
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
  );
  // runApp(const MyApp());
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zyppi Ride',
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
      // home: const SplashScreen(),
      routerConfig: AppRouter.router,
      // routes: {
      //   '/auth': (context) => const AuthScreen(),
      //   '/dashboard': (context) => const MainDashboard(),
      // },
    );
  }
}