import 'package:flutter/material.dart';
import '../../services/booking_service.dart';

/// Card widget for displaying driver statistics
class DriverStatsCard extends StatelessWidget {
  final BookingStats stats;
  final bool isLoading;

  const DriverStatsCard({
    super.key,
    required this.stats,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.attach_money,
            value: '₹${stats.totalSpent.toStringAsFixed(0)}',
            label: 'Earnings',
            color: Colors.green,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.check_circle_outline,
            value: '${stats.completedBookings}',
            label: 'Trips',
            color: Colors.blue,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.route,
            value: '${stats.totalDistance.toStringAsFixed(0)} km',
            label: 'Distance',
            color: Colors.orange,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.trending_up,
            value: '${stats.completionRate.toStringAsFixed(0)}%',
            label: 'Rate',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.grey.shade200,
    );
  }
}

/// Compact stats row for dashboard header
class DriverQuickStats extends StatelessWidget {
  final int pendingCount;
  final bool hasActiveRide;
  final double todayEarnings;

  const DriverQuickStats({
    super.key,
    required this.pendingCount,
    required this.hasActiveRide,
    required this.todayEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildQuickStat(
          icon: Icons.notifications_active,
          value: '$pendingCount',
          label: 'Requests',
          color: pendingCount > 0 ? Colors.orange : Colors.grey,
          highlight: pendingCount > 0,
        ),
        const SizedBox(width: 12),
        _buildQuickStat(
          icon: Icons.directions_car,
          value: hasActiveRide ? '1' : '0',
          label: 'Active',
          color: hasActiveRide ? Colors.green : Colors.grey,
          highlight: hasActiveRide,
        ),
        const SizedBox(width: 12),
        _buildQuickStat(
          icon: Icons.account_balance_wallet,
          value: '₹${todayEarnings.toStringAsFixed(0)}',
          label: 'Today',
          color: Colors.blue,
          highlight: false,
        ),
      ],
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool highlight,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
