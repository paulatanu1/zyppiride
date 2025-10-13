import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zyppi_ride/screens/main_dashboard.dart';
import 'package:go_router/go_router.dart';


class EmergencyScreen extends StatelessWidget {
  final String? userId;
  
  const EmergencyScreen({super.key, this.userId});

  Future<void> _callAmbulance() async {
    final Uri launchUri = Uri(scheme: 'tel', path: '108');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print('Could not launch dial pad');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            print('Back button pressed on EmergencyScreen - navigating to Dashboard');
            if (userId != null) {
              // Clear navigation stack and go to Dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainDashboard(),
                ),
                (route) => false, // Remove all previous routes
              );
            } else {
              // If no userId provided, try to pop or go to a default route
              if (Navigator.canPop(context)) {
                context.go('/dashboard?userId=$userId');
              } else {
                Navigator.pushReplacementNamed(context, '/dashboard');
              }
            }
          },
        ),
        title: const Text('Emergency', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent default back button
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emergency,
              size: 100,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Emergency Call',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap to call Ambulance (108)',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _callAmbulance,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Call Ambulance',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}