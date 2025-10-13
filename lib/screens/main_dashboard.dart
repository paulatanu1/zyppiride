import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zyppi_ride/screens/dashboard_screen.dart';
import 'profile_screen.dart'; // New profile screen
import 'emergency_screen.dart'; // New emergency screen

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  final List<Widget> _screens = [
    DashboardScreen(userId: FirebaseAuth.instance.currentUser!.uid), // Overview tab
    ProfileScreen(userId: FirebaseAuth.instance.currentUser!.uid), // Profile tab
    EmergencyScreen(), // Emergency tab
  ];

  Future<void> _logout(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging out...')),
      );
      await FirebaseAuth.instance.signOut();
      // Navigate to auth screen
      if (context.mounted) {
        context.go('/auth');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Zyppi Ride', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // For more than 3 items, but here it's 3
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
        ],
      ),
    );
  }
}

// Simple overview tab (replace with your dashboard content)
class DashboardOverview extends StatelessWidget {
  final String userId;

  const DashboardOverview({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading data', style: TextStyle(fontFamily: 'Poppins')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No data available', style: TextStyle(fontFamily: 'Poppins')));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final fullName = data['fullName'] ?? 'User';
        final email = data['email'] ?? 'No email';

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
              Text(
                'Email: $email',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                ),
              ),
              // Add role-based features here
              if (data['role'] == 'Driver') ...[
                const Text('Driver Features: Book Rides', style: TextStyle(fontFamily: 'Poppins')),
              ],
            ],
          ),
        );
      },
    );
  }
}