// lib/router/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zyppi_ride/screens/emergency_screen.dart';
import 'package:zyppi_ride/screens/login_screen.dart';
import 'package:zyppi_ride/screens/register_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/main_dashboard.dart';
import '../screens/profile_screen.dart';
import '../screens/vehicle_list_screen.dart'; // NEW
import '../screens/vehicle_registration_screen.dart';
import '../screens/vehicle_view_screen.dart';
import '../screens/vehicle_edit_screen.dart';
import '../screens/document_upload_screen.dart';
import '../screens/agreement_signing_screen.dart';
import '../screens/ride_history_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/active_vehicles_screen.dart';
import '../screens/delivery_requests_screen.dart';
import '../screens/support_center_screen.dart';
import '../screens/availability_screen.dart';
import '../screens/promotions_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String userId;

  const PlaceholderScreen({super.key, required this.title, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          '$title\nUser ID: $userId',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/registration',
        name: 'registration',
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainDashboard(),
      ),

      // Add profile route with userId parameter
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) {
          String userId = state.queryParameters["userId"] as String;
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/emergency',
        name: 'emergency',
        builder: (context, state) {
          String userId = state.queryParameters["userId"] as String;
          return EmergencyScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/mainDashboard',
        name: 'mainDashboard',
        builder: (context, state) {
          return MainDashboard();
        },
      ),

      // ============================================
      // VEHICLE MANAGEMENT ROUTES (COMPLETE FLOW)
      // ============================================

      // 1. Vehicle List (Main Entry Point) - NEW
      GoRoute(
        path: '/vehicle-list',
        name: 'vehicle-list',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return VehicleListScreen(userId: userId);
        },
      ),

      // 2. Vehicle Registration (Add New Vehicle)
      GoRoute(
        path: '/vehicle-registration',
        name: 'vehicle-registration',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return VehicleRegistrationScreen(userId: userId);
        },
      ),

      // 3. Vehicle View (After registration or from dashboard)
      GoRoute(
        path: '/vehicle-view',
        name: 'vehicle-view',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          final vehicleId = state.queryParameters['vehicleId'] ?? '';
          return VehicleViewScreen(
            userId: userId,
            vehicleId: vehicleId,
          );
        },
      ),

      // 4. Vehicle Edit (From view screen)
      GoRoute(
        path: '/vehicle-edit',
        name: 'vehicle-edit',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          final vehicleId = state.queryParameters['vehicleId'] ?? '';
          return VehicleEditScreen(
            userId: userId,
            vehicleId: vehicleId,
          );
        },
      ),

      // ============================================
      // OTHER ROUTES
      // ============================================

      GoRoute(
        path: '/document-upload',
        name: 'document-upload',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return DocumentUploadScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/agreement-signing',
        name: 'agreement-signing',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return AgreementSigningScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/ride-history',
        name: 'ride-history',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return RideHistoryScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return NotificationsScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/active-vehicles',
        name: 'active-vehicles',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return ActiveVehiclesScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/delivery-requests',
        name: 'delivery-requests',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return DeliveryRequestsScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/support-center',
        name: 'support-center',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return SupportCenterScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/availability',
        name: 'availability',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return AvailabilityScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/promotions',
        name: 'promotions',
        builder: (context, state) {
          final userId = state.queryParameters['userId'] ?? '';
          return PromotionsScreen(userId: userId);
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found: ${state.error}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/splash'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}