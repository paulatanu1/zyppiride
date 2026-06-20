import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/active_booking_model.dart';
import '../providers/user_dashboard_provider.dart';
import '../router/routes_name.dart';

// ── Theme constants (mirrors dashboard palette) ───────────────────────────────
const Color _kBrand   = Color(0xFF4F46E5);
const Color _kBgLight = Color(0xFFF4F6FA);
const Color _kSurface = Colors.white;
const Color _kTextPri = Color(0xFF111827);
const Color _kTextSec = Color(0xFF6B7280);
const Color _kSuccess = Color(0xFF10B981);
const Color _kWarning = Color(0xFFF59E0B);
const Color _kError   = Color(0xFFEF4444);
// ─────────────────────────────────────────────────────────────────────────────

class RideHistoryScreen extends ConsumerStatefulWidget {
  final String userId;

  const RideHistoryScreen({super.key, required this.userId});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Completed', 'Cancelled', 'Ongoing'];

  static const _ongoingStatuses = {
    'pending', 'confirmed', 'driverArriving', 'arrived', 'inProgress',
  };

  List<ActiveBooking> _applyFilter(List<ActiveBooking> items) {
    if (_filter == 'All') return items;
    if (_filter == 'Ongoing') {
      return items.where((b) => _ongoingStatuses.contains(b.status)).toList();
    }
    final status = _filter.toLowerCase();
    return items.where((b) => b.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(bookingHistoryProvider(widget.userId));
    final allItems = historyState.items;
    final filtered = _applyFilter(allItems);

    final completedCount = allItems.where((b) => b.status == 'completed').length;
    final totalSpent = allItems
        .where((b) => b.status == 'completed')
        .fold<double>(0, (sum, b) => sum + b.fare);

    return Scaffold(
      backgroundColor: _kBrand,
      body: Column(
        children: [
          // ── Purple header ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/user-dashboard'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Ride History',
                          style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 20,
                            fontWeight: FontWeight.bold, color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Stats row ────────────────────────────────────────────
                  if (allItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _buildStat('$completedCount', 'Completed'),
                          _vDivider(),
                          _buildStat('₹${totalSpent.toStringAsFixed(0)}', 'Total Spent'),
                          _vDivider(),
                          _buildStat('${allItems.length}', 'Total Rides'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── White body ─────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kBgLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  _buildFilterTabs(),
                  Expanded(child: _buildBody(filtered, historyState.isLoading)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 16,
                fontWeight: FontWeight.bold, color: Colors.white,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              )),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 32,
        color: Colors.white.withValues(alpha: 0.25),
      );

  Widget _buildFilterTabs() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final f = _filters[i];
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? _kBrand : _kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _kBrand : const Color(0xFFE5E7EB),
                ),
                boxShadow: selected
                    ? [BoxShadow(
                        color: _kBrand.withValues(alpha: 0.25),
                        blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(f,
                  style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _kTextSec,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<ActiveBooking> items, bool isLoading) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kBrand));
    }
    if (items.isEmpty) return _buildEmpty();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200) {
          ref.read(bookingHistoryProvider(widget.userId).notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        itemCount: items.length + (isLoading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: _kBrand)),
            );
          }
          return _buildCard(items[i]);
        },
      ),
    );
  }

  Widget _buildCard(ActiveBooking booking) {
    final Color statusColor;
    final IconData statusIcon;

    switch (booking.status) {
      case 'completed':
        statusColor = _kSuccess; statusIcon = Icons.check_circle_outline;
      case 'cancelled':
        statusColor = _kError; statusIcon = Icons.cancel_outlined;
      default:
        statusColor = _kWarning; statusIcon = Icons.access_time_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.vehicleType,
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 15,
                            fontWeight: FontWeight.bold, color: _kTextPri,
                          )),
                      Text(_formatDate(booking.bookingTime),
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, color: _kTextSec,
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${booking.fare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 17,
                          fontWeight: FontWeight.bold, color: _kTextPri,
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking.status == 'inProgress'
                            ? 'ONGOING'
                            : booking.status.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 9,
                          fontWeight: FontWeight.bold, color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),

            // Route
            if (booking.pickupLocation.isNotEmpty)
              _buildRouteRow(
                Icons.radio_button_checked, _kSuccess, booking.pickupLocation),
            if (booking.pickupLocation.isNotEmpty && booking.dropLocation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  children: List.generate(3, (_) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    width: 1.5, height: 4,
                    color: const Color(0xFFD1D5DB),
                  )),
                ),
              ),
            if (booking.dropLocation.isNotEmpty)
              _buildRouteRow(
                Icons.location_on, _kError, booking.dropLocation),

            const SizedBox(height: 12),

            // Driver row
            Row(
              children: [
                const Icon(Icons.person_outline, size: 15, color: _kTextSec),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(booking.driverName,
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: _kTextSec,
                      )),
                ),
                if (booking.status == 'inProgress' || booking.status == 'confirmed')
                  TextButton.icon(
                    onPressed: () => context.pushNamed(
                      RoutesName.trackActiveBooking,
                    ),
                    icon: const Icon(Icons.gps_fixed, size: 14),
                    label: const Text('Track',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _kBrand,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: _kTextPri,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, size: 48, color: _kBrand),
          ),
          const SizedBox(height: 20),
          Text(
            _filter == 'All' ? 'No rides yet' : 'No $_filter rides',
            style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 17,
              fontWeight: FontWeight.bold, color: _kTextPri,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your completed rides will appear here',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kTextSec),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }
}
