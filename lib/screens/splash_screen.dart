import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/test_mode.dart';
import '../core/utils/app_logger.dart';
import '../router/routes_name.dart';
import '../widgets/mandala_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _mandalaController;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _mandalaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for minimum splash duration
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted || _hasNavigated) return;

      // Check current user
      final user = FirebaseAuth.instance.currentUser;

      _hasNavigated = true;

      if (user != null) {
        // Get user role from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection(TestMode.usersCollection)
            .doc(user.uid)
            .get();

        if (!mounted) return; // Check mounted after async operation

        final role = userDoc.data()?['role'];

        // Debug logs
        AppLogger.debug('Current user: ${userDoc.data()}', tag: 'Splash');
        AppLogger.debug('User role: $role', tag: 'Splash');
        AppLogger.debug('user details: $user', tag: 'Splash');

        // Navigate based on role
        if (role == 'User') {
          context.goNamed('user-dashboard');
        } else if (role == 'Driver' || role == 'Vehicle Owner') {
          // Recover mid-trip state: if the driver had an active booking when
          // the app was killed, send them straight back to the booking dashboard
          // so they can see the current trip without hunting for it manually.
          final hasActiveTrip = await _hasActiveDriverTrip(user.uid);
          if (!mounted) return;
          if (hasActiveTrip) {
            AppLogger.info(
              'Active trip detected on launch — resuming driver booking dashboard',
              tag: 'Splash',
            );
            context.goNamed(RoutesName.driverBookingDashboard);
          } else {
            context.goNamed('mainDashboard');
          }
        } else {
          // Default fallback if role is null or unexpected - go to role selection
          AppLogger.warning('Unknown or missing role: $role, redirecting to role selection', tag: 'Splash');
          context.goNamed('role-selection', queryParameters: {'userId': user.uid});
        }
      } else {
        // User is not logged in
        if (!mounted) return;
        context.goNamed('auth');
      }
    } catch (e) {
      AppLogger.error('Error in splash initialization', tag: 'Splash', error: e);
      if (mounted && !_hasNavigated) {
        _hasNavigated = true;
        context.goNamed('auth');
      }
    }
  }

  /// Returns true when the driver has at least one booking in an active
  /// lifecycle state (confirmed → arriving → arrived → inProgress).
  /// Called on launch so the app can restore mid-trip state after a kill.
  Future<bool> _hasActiveDriverTrip(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(TestMode.bookingsCollection)
          .where('driver.driverId', isEqualTo: uid)
          .where('status', whereIn: [
            'confirmed',
            'driverArriving',
            'arrived',
            'inProgress',
          ])
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      AppLogger.error(
        'Active trip check failed — defaulting to main dashboard',
        tag: 'Splash',
        error: e,
      );
      return false; // Fail safe: go to main dashboard, driver can navigate manually
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _mandalaController.dispose();
    super.dispose();
  }

  Widget _buildMandala({required double size, required double alpha, bool reverse = false}) {
    return RotationTransition(
      turns: reverse
          ? ReverseAnimation(_mandalaController)
          : _mandalaController,
      child: CustomPaint(
        size: Size.square(size),
        painter: MandalaPainter(color: Colors.white.withValues(alpha: alpha)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -120,
            child: _buildMandala(size: 320, alpha: 0.10),
          ),
          Positioned(
            bottom: -140,
            right: -140,
            child: _buildMandala(size: 400, alpha: 0.12, reverse: true),
          ),
          Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/zyppi_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    AppLogger.error('Logo asset error', tag: 'Splash', error: error);
                    return const Icon(
                      Icons.local_taxi,
                      size: 80,
                      color: Colors.deepPurple,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _controller,
              child: const Text(
                'Zyppi Ride',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),
            FadeTransition(
              opacity: _controller,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}
