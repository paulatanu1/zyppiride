import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTiles extends StatelessWidget {
  final String userId;
  final String role;

  const DashboardTiles({super.key, required this.userId, required this.role});

  // Define tile data: title, icon, gradient, and route
  static final List<Map<String, dynamic>> _tiles = [
    {
      'title': 'Vehicle Registration',
      'icon': Icons.directions_car,
      'gradient': const LinearGradient(
        colors: [Colors.blue, Colors.blueAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/vehicle-list', // UPDATED: Changed from /vehicle-registration to /vehicle-list
    },
    {
      'title': 'Document Upload',
      'icon': Icons.upload_file,
      'gradient': const LinearGradient(
        colors: [Colors.green, Colors.greenAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/document-upload',
    },
    {
      'title': 'Agreement Signing',
      'icon': Icons.description,
      'gradient': const LinearGradient(
        colors: [Colors.purple, Colors.purpleAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/agreement-signing',
    },
    {
      'title': 'Ride History',
      'icon': Icons.history,
      'gradient': const LinearGradient(
        colors: [Colors.orange, Colors.deepOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/ride-history',
    },
    {
      'title': 'Notifications',
      'icon': Icons.notifications,
      'gradient': const LinearGradient(
        colors: [Colors.red, Colors.redAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/notifications',
    },
    {
      'title': 'Active Vehicles',
      'icon': Icons.car_rental,
      'gradient': const LinearGradient(
        colors: [Colors.teal, Colors.tealAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/active-vehicles',
    },
    {
      'title': 'Delivery Requests',
      'icon': Icons.local_shipping,
      'gradient': const LinearGradient(
        colors: [Colors.indigo, Colors.indigoAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/delivery-requests',
    },
    {
      'title': 'Support Center',
      'icon': Icons.support_agent,
      'gradient': const LinearGradient(
        colors: [Colors.cyan, Colors.cyanAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/support-center',
    },
    {
      'title': 'Availability',
      'icon': Icons.schedule,
      'gradient': const LinearGradient(
        colors: [Colors.amber, Colors.amberAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/availability',
    },
    {
      'title': 'Promotions',
      'icon': Icons.local_offer,
      'gradient': const LinearGradient(
        colors: [Colors.pink, Colors.pinkAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/promotions',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Only show tiles for Vehicle Owner or Driver
    if (role != 'Vehicle Owner' && role != 'Driver') {
      return const SizedBox.shrink(); // Hide tiles for other roles
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(5.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Square tiles
      ),
      itemCount: _tiles.length,
      itemBuilder: (context, index) {
        final tile = _tiles[index];
        return GestureDetector(
          onTap: () {
            FirebaseAnalytics.instance.logEvent(
              name: 'tile_tapped',
              parameters: {'tile': tile['title'], 'userId': userId},
            );
            context.go('${tile['route']}?userId=$userId');
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              decoration: BoxDecoration(
                gradient: tile['gradient'],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tile['icon'],
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tile['title'],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}