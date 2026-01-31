// lib/router/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zyppi_ride/screens/emergency_screen.dart';
import 'package:zyppi_ride/screens/login_screen.dart';
import 'package:zyppi_ride/screens/register_screen.dart';
import 'package:zyppi_ride/screens/phone_auth_screen.dart';
import 'package:zyppi_ride/screens/forgot_password_screen.dart';
import 'package:zyppi_ride/screens/email_verification_screen.dart';
import 'package:zyppi_ride/screens/role_selection_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/main_dashboard.dart';
import '../screens/profile_screen.dart';
import '../screens/vehicle_list_screen.dart';
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
import '../screens/weekly_schedule_screen.dart';
import '../screens/driver_availability_screen.dart';
import 'package:zyppi_ride/screens/user/user_dashboard.dart';
import 'package:zyppi_ride/screens/user/user_profile_screen.dart';
import 'package:zyppi_ride/screens/user/reserve_vehicle_screen.dart';
import 'package:zyppi_ride/screens/user/vehicle_details_screen.dart';
import 'package:zyppi_ride/screens/driver/driver_profile_screen.dart';
import 'package:zyppi_ride/screens/user/book_goods_carrier_screen.dart';
import 'package:zyppi_ride/screens/user/track_booking_screen.dart';
import 'package:zyppi_ride/screens/user/ride_history_screen.dart' as user_ride_history;
import 'package:zyppi_ride/screens/user/offers_rewards_screen.dart';
import 'package:zyppi_ride/screens/user/local_transport_screen.dart';
import 'package:zyppi_ride/screens/user/outstation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes_name.dart';

class AppRouter {
  // Public routes that don't require authentication
  static const List<String> _publicRoutes = [
    '/splash',
    '/auth',
    '/login',
    '/registration',
    '/phone-auth',
    '/forgot-password',
    '/email-verification',
    '/role-selection',
  ];

  // Check if route requires authentication
  static bool _isProtectedRoute(String location) {
    return !_publicRoutes.any((route) => location.startsWith(route));
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',

    // Global authentication redirect
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final currentPath = state.uri.path;

      // Allow public routes without authentication
      if (!_isProtectedRoute(currentPath)) {
        return null;
      }

      // Redirect to login if not authenticated and trying to access protected route
      if (!isLoggedIn && _isProtectedRoute(currentPath)) {
        return '/login';
      }

      return null;
    },

    routes: [
      // ============================================
      // PUBLIC ROUTES (No Auth Required)
      // ============================================

      GoRoute(
        path: '/splash',
        name: RoutesName.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/auth',
        name: RoutesName.auth,
        builder: (context, state) => const AuthScreen(),
      ),

      GoRoute(
        path: '/login',
        name: RoutesName.login,
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/registration',
        name: RoutesName.registration,
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: '/phone-auth',
        name: RoutesName.phoneAuth,
        builder: (context, state) => const PhoneAuthScreen(),
      ),

      GoRoute(
        path: '/forgot-password',
        name: RoutesName.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: '/email-verification',
        name: RoutesName.emailVerification,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return EmailVerificationScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/role-selection',
        name: RoutesName.roleSelection,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return RoleSelectionScreen(userId: userId);
        },
      ),

      // ============================================
      // DASHBOARD ROUTES (Auth Required - handled by global redirect)
      // ============================================

      GoRoute(
        path: '/dashboard',
        name: RoutesName.dashboard,
        builder: (context, state) => const MainDashboard(),
      ),

      GoRoute(
        path: '/mainDashboard',
        name: RoutesName.mainDashboard,
        builder: (context, state) => const MainDashboard(),
      ),

      GoRoute(
        path: '/user-dashboard',
        name: RoutesName.userDashboard,
        builder: (context, state) => const UserDashboard(),
      ),

      // ============================================
      // RESERVE VEHICLE ROUTE
      // ============================================

      GoRoute(
        path: '/reserve-vehicle',
        name: RoutesName.reserveVehicle,
        builder: (context, state) => const ReserveVehicleScreen(),
      ),

      GoRoute(
        path: '/vehicle-details',
        name: 'vehicle-details',
        builder: (context, state) {
          final vehicleId = state.uri.queryParameters['vehicleId'];
          return VehicleDetailsScreen(vehicleId: vehicleId);
        },
      ),

      // ============================================
      // USER BOOKING ROUTES
      // ============================================

      GoRoute(
        path: '/book-goods-carrier',
        name: RoutesName.bookGoodsCarrier,
        builder: (context, state) => const BookGoodsCarrierScreen(),
      ),

      GoRoute(
        path: '/track-booking',
        name: RoutesName.trackActiveBooking,
        builder: (context, state) => const TrackBookingScreen(),
      ),

      GoRoute(
        path: '/user-ride-history',
        name: 'user-ride-history',
        builder: (context, state) => const user_ride_history.UserRideHistoryScreen(),
      ),

      GoRoute(
        path: '/offers-rewards',
        name: RoutesName.offersRewards,
        builder: (context, state) => const OffersRewardsScreen(),
      ),

      GoRoute(
        path: '/local-transport',
        name: RoutesName.localTransport,
        builder: (context, state) => const LocalTransportScreen(),
      ),

      GoRoute(
        path: '/outstation',
        name: RoutesName.outstationRental,
        builder: (context, state) => const OutstationScreen(),
      ),

      // ============================================
      // PROFILE ROUTES
      // ============================================

      // Legacy profile route (kept for backward compatibility)
      GoRoute(
        path: '/profile',
        name: RoutesName.profile,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ??
              FirebaseAuth.instance.currentUser?.uid ?? '';
          return ProfileScreen(userId: userId);
        },
      ),

      // User Profile Screen (Modern Design)
      GoRoute(
        path: '/user-profile',
        name: 'user-profile',
        builder: (context, state) => const UserProfileScreen(),
      ),

      // Driver Profile Screen (Modern Design)
      GoRoute(
        path: '/driver-profile',
        name: 'driver-profile',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ??
              FirebaseAuth.instance.currentUser?.uid ?? '';
          return DriverProfileScreen(userId: userId);
        },
      ),

      // ============================================
      // VEHICLE MANAGEMENT ROUTES
      // ============================================

      GoRoute(
        path: '/vehicle-list',
        name: RoutesName.vehicleList,
        builder: (context, state) {
          final userId = _getUserId(state);
          return VehicleListScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/vehicle-registration',
        name: RoutesName.vehicleRegistration,
        builder: (context, state) {
          final userId = _getUserId(state);
          return VehicleRegistrationScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/vehicle-view',
        name: RoutesName.vehicleView,
        builder: (context, state) {
          final userId = _getUserId(state);
          final vehicleId = state.uri.queryParameters['vehicleId'] ?? '';
          return VehicleViewScreen(userId: userId, vehicleId: vehicleId);
        },
      ),

      GoRoute(
        path: '/vehicle-edit',
        name: RoutesName.vehicleEdit,
        builder: (context, state) {
          final userId = _getUserId(state);
          final vehicleId = state.uri.queryParameters['vehicleId'] ?? '';
          return VehicleEditScreen(userId: userId, vehicleId: vehicleId);
        },
      ),

      // ============================================
      // DOCUMENT & AGREEMENT ROUTES
      // ============================================

      GoRoute(
        path: '/document-upload',
        name: RoutesName.documentUpload,
        builder: (context, state) {
          final userId = _getUserId(state);
          return DocumentUploadScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/agreement-signing',
        name: RoutesName.agreementSigning,
        builder: (context, state) {
          final userId = _getUserId(state);
          return AgreementSigningScreen(userId: userId);
        },
      ),

      // ============================================
      // BOOKING & HISTORY ROUTES
      // ============================================

      GoRoute(
        path: '/ride-history',
        name: RoutesName.rideHistory,
        builder: (context, state) {
          final userId = _getUserId(state);
          return RideHistoryScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/active-vehicles',
        name: RoutesName.activeVehicles,
        builder: (context, state) {
          final userId = _getUserId(state);
          return ActiveVehiclesScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/delivery-requests',
        name: RoutesName.deliveryRequests,
        builder: (context, state) {
          final userId = _getUserId(state);
          return DeliveryRequestsScreen(userId: userId);
        },
      ),

      // ============================================
      // NOTIFICATIONS & SUPPORT ROUTES
      // ============================================

      GoRoute(
        path: '/notifications',
        name: RoutesName.notifications,
        builder: (context, state) {
          final userId = _getUserId(state);
          return NotificationsScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/support-center',
        name: RoutesName.supportCenter,
        builder: (context, state) {
          final userId = _getUserId(state);
          return SupportCenterScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/emergency',
        name: RoutesName.emergency,
        builder: (context, state) {
          final userId = _getUserId(state);
          return EmergencyScreen(userId: userId);
        },
      ),

      // ============================================
      // AVAILABILITY & SCHEDULE ROUTES
      // ============================================

      GoRoute(
        path: '/availability',
        name: RoutesName.availability,
        builder: (context, state) {
          final userId = _getUserId(state);
          return AvailabilityScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/driver-availability',
        name: RoutesName.driverAvailability,
        builder: (context, state) {
          final userId = _getUserId(state);
          final vehicleId = state.uri.queryParameters['vehicleId'] ?? '';
          return DriverAvailabilityScreen(userId: userId, vehicleId: vehicleId);
        },
      ),

      GoRoute(
        path: '/manage-schedule',
        name: RoutesName.manageSchedule,
        builder: (context, state) {
          final userId = _getUserId(state);
          final vehicleId = state.uri.queryParameters['vehicleId'] ?? '';
          return WeeklyScheduleScreen(userId: userId, vehicleId: vehicleId);
        },
      ),

      // ============================================
      // PROMOTIONS ROUTE
      // ============================================

      GoRoute(
        path: '/promotions',
        name: RoutesName.promotions,
        builder: (context, state) {
          final userId = _getUserId(state);
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
              'Page not found: ${state.uri.path}',
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

  // Helper method to get userId - prefers query param, falls back to Firebase Auth
  static String _getUserId(GoRouterState state) {
    return state.uri.queryParameters['userId'] ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
  }
}
