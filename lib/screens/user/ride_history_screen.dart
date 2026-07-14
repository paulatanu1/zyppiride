import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class UserRideHistoryScreen extends ConsumerStatefulWidget {
  const UserRideHistoryScreen({super.key});

  @override
  ConsumerState<UserRideHistoryScreen> createState() => _UserRideHistoryScreenState();
}

class _UserRideHistoryScreenState extends ConsumerState<UserRideHistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Completed', 'Cancelled', 'Ongoing'];

  // Mock ride history data
  final List<Map<String, dynamic>> _rideHistory = [
    {
      'id': 'ZYP001',
      'date': DateTime.now().subtract(const Duration(hours: 2)),
      'pickup': 'Salt Lake Sector V',
      'drop': 'Park Street',
      'fare': 185,
      'status': 'completed',
      'vehicleType': 'Sedan',
      'driverName': 'Rahul Kumar',
      'distance': '8.5 km',
      'duration': '25 min',
      'rating': 5,
    },
    {
      'id': 'ZYP002',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'pickup': 'Howrah Station',
      'drop': 'Airport',
      'fare': 450,
      'status': 'completed',
      'vehicleType': 'SUV',
      'driverName': 'Amit Singh',
      'distance': '22 km',
      'duration': '45 min',
      'rating': 4,
    },
    {
      'id': 'ZYP003',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'pickup': 'Esplanade',
      'drop': 'New Town',
      'fare': 320,
      'status': 'cancelled',
      'vehicleType': 'Sedan',
      'driverName': 'Vikram Pal',
      'distance': '15 km',
      'duration': '-',
      'rating': null,
    },
    {
      'id': 'ZYP004',
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'pickup': 'Jadavpur',
      'drop': 'Sealdah',
      'fare': 145,
      'status': 'completed',
      'vehicleType': 'Auto',
      'driverName': 'Suresh Das',
      'distance': '6 km',
      'duration': '20 min',
      'rating': 5,
    },
    {
      'id': 'ZYP005',
      'date': DateTime.now(),
      'pickup': 'Salt Lake City Center',
      'drop': 'Rajarhat',
      'fare': 220,
      'status': 'ongoing',
      'vehicleType': 'Sedan',
      'driverName': 'Manoj Kumar',
      'distance': '10 km',
      'duration': '-',
      'rating': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRides {
    if (_selectedFilter == 'All') return _rideHistory;
    return _rideHistory
        .where((r) => r['status'].toString().toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade800,
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                _buildStatsRow(),
                _buildFilterChips(),
                Expanded(
                  child: _buildRideList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/user-dashboard');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Ride History',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final completedRides = _rideHistory.where((r) => r['status'] == 'completed').length;
    final totalSpent = _rideHistory
        .where((r) => r['status'] == 'completed')
        .fold<int>(0, (sum, r) => sum + (r['fare'] as int));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total Rides', '$completedRides', Icons.directions_car),
            Container(height: 40, width: 1, color: Colors.white24),
            _buildStatItem('Total Spent', '₹$totalSpent', Icons.currency_rupee),
            Container(height: 40, width: 1, color: Colors.white24),
            _buildStatItem('This Month', '${_rideHistory.length}', Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = _selectedFilter == filter;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.deepPurple : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRideList() {
    final rides = _filteredRides;

    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No rides found',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        return _buildRideCard(rides[index]);
      },
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final status = ride['status'] as String;
    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'cancelled'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'cancelled'
                            ? Icons.cancel
                            : Icons.pending,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride['vehicleType'],
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _formatDate(ride['date']),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${ride['fare']}',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Locations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildLocationRow(Icons.circle, Colors.green, ride['pickup']),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Column(
                        children: List.generate(
                          2,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            width: 2,
                            height: 4,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildLocationRow(Icons.location_on, Colors.red, ride['drop']),
              ],
            ),
          ),
          // Footer
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white24,
                      child: Text(
                        ride['driverName'][0],
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ride['driverName'],
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      ride['distance'],
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (ride['rating'] != null) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        '${ride['rating']}',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Receipt / Rebook actions hidden until implemented (v2) —
          // dead buttons fail Play review.
          if (status == 'ongoing')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/track-booking?bookingId=${ride['id']}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Track Ride',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String location) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            location,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 13,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inHours < 24) {
      if (diff.inHours < 1) {
        return '${diff.inMinutes} mins ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }
}
