import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../widgets/dashboard_tiles.dart';
import 'dart:developer';

class DashboardScreen extends StatefulWidget {
  final String userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _userData;
  bool _isDataLoaded = false;
  DateTime? _lastPressedAt;

  Future<void> _callAmbulance() async {
    final Uri uri = Uri(scheme: 'tel', path: '101');
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_isDataLoaded) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (snapshot.exists && mounted) {
        setState(() {
          _userData = snapshot.data() as Map<String, dynamic>;
          _isDataLoaded = true;
        });
      }
    } catch (e, stackTrace) {
      log('Error occurred', error: e, stackTrace: stackTrace);
    }
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrHasBeenPressedLongTimeAgo =
        _lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2);

    if (backButtonHasNotBeenPressedOrHasBeenPressedLongTimeAgo) {
      _lastPressedAt = now;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Press back again to exit',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.black26,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return false; // Don't exit
    }

    return true; // Exit app
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is the root route (can't pop further)
    final canPopRoute = GoRouter.of(context).canPop();

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // Use our custom logic
        final shouldExit = await _onWillPop();

        if (shouldExit && mounted) {
          // If we can pop in GoRouter, do that
          if (canPopRoute) {
            if (context.mounted) {
              context.pop();
            }
          } else {
            // Otherwise exit app
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: _isDataLoaded && _userData != null
              ? _buildDashboardContent(_userData!)
              : FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading data: ${snapshot.error}',
                    style: const TextStyle(fontFamily: 'Poppins'),
                  ),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isDataLoaded) {
                  setState(() {
                    _userData = data;
                    _isDataLoaded = true;
                  });
                }
              });

              return _buildDashboardContent(data);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Map<String, dynamic> data) {
    final fullName = data['fullName'] ?? 'User';
    final role = data['role'] ?? 'Passenger';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $fullName!',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 20),
          DashboardTiles(userId: widget.userId, role: role),
        ],
      ),
    );
  }
}
