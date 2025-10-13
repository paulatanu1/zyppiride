import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/dashboard_tiles.dart'; // Import the new widget

class DashboardScreen extends StatefulWidget {
  final String userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _userData;
  bool _isDataLoaded = false;

  Future<void> _callAmbulance() async {
    final Uri uri = Uri(scheme: 'tel', path: '108');
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    print('DashboardScreen initState with userId: ${widget.userId}');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_isDataLoaded) return; // Don't reload if already loaded

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
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DashboardScreen build with userId: ${widget.userId}');
    return Scaffold(

      body: SingleChildScrollView(
        child: _isDataLoaded && _userData != null
            ? _buildDashboardContent(_userData!)
            : FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get(),
          builder: (context, snapshot) {
            print('Loading data for userId: ${widget.userId}');
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('Waiting for data...');
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print('Error: ${snapshot.error}');
              return Center(
                child: Text(
                  'Error loading data: ${snapshot.error}',
                  style: const TextStyle(fontFamily: 'Poppins'),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              print('No data or document does not exist');
              return const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            // Cache the data
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
    );
  }

  Widget _buildDashboardContent(Map<String, dynamic> data) {
    final fullName = data['fullName'] ?? 'User';
    final email = data['email'] ?? 'No email';
    final role = data['role'] ?? 'Passenger'; // Default to Passenger if no role

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
          DashboardTiles(userId: widget.userId, role: role), // Pass role
        ],
      ),
    );
  }
}