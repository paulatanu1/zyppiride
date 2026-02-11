import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/booking/pending_booking_card.dart';
import '../../widgets/booking/active_ride_card.dart';
import '../../widgets/booking/driver_stats_card.dart';
import '../../widgets/driver/driver_online_toggle.dart';
import '../../core/utils/app_logger.dart';

/// Main dashboard screen for drivers to manage bookings
class DriverBookingDashboardScreen extends ConsumerStatefulWidget {
  const DriverBookingDashboardScreen({super.key});

  @override
  ConsumerState<DriverBookingDashboardScreen> createState() =>
      _DriverBookingDashboardScreenState();
}

class _DriverBookingDashboardScreenState
    extends ConsumerState<DriverBookingDashboardScreen> {
  String _otpInput = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Refresh driver data on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverBookingProvider.notifier).loadActiveRide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverBookingProvider);
    final pendingRequestsAsync = ref.watch(driverPendingRequestsProvider);
    final statsAsync = ref.watch(driverBookingStatsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Driver Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // Online Status Toggle
            SliverToBoxAdapter(
              child: Container(
                color: Colors.deepPurple,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: const DriverOnlineStatusCard(userId: ''),
              ),
            ),

            // Stats Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: statsAsync.when(
                  data: (stats) => DriverStatsCard(stats: stats),
                  loading: () => DriverStatsCard(
                    stats: BookingStats.empty(),
                    isLoading: true,
                  ),
                  error: (error, stack) => DriverStatsCard(
                    stats: BookingStats.empty(),
                  ),
                ),
              ),
            ),

            // Active Ride Section
            if (driverState.activeRide != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Ride',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ActiveRideCard(
                        booking: driverState.activeRide!,
                        isLoading: _isProcessing || driverState.isLoading,
                        otpInput: _otpInput,
                        onOtpChanged: (value) {
                          setState(() => _otpInput = value);
                        },
                        onArrived: () => _handleArrived(driverState.activeRide!),
                        onStartTrip: () =>
                            _handleStartTrip(driverState.activeRide!),
                        onComplete: () =>
                            _handleComplete(driverState.activeRide!),
                        onNavigate: () =>
                            _handleNavigate(driverState.activeRide!),
                      ),
                    ],
                  ),
                ),
              ),

            // Pending Requests Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking Requests',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    pendingRequestsAsync.when(
                      data: (requests) => requests.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${requests.length} new',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // Pending Requests List
            pendingRequestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final booking = requests[index];
                        return PendingBookingCard(
                          booking: booking,
                          isLoading: driverState.isLoading,
                          onAccept: () => _handleAccept(booking),
                          onReject: () => _handleReject(booking),
                        );
                      },
                      childCount: requests.length,
                    ),
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: _buildLoadingState(),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _buildErrorState(error.toString()),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No booking requests',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests will appear here when customers book nearby.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load requests',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _refreshData,
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    ref.invalidate(driverPendingRequestsProvider);
    ref.invalidate(driverBookingStatsProvider);
    await ref.read(driverBookingProvider.notifier).loadActiveRide();
  }

  Future<void> _handleAccept(Booking booking) async {
    final confirmed = await _showConfirmDialog(
      title: 'Accept Booking',
      message: 'Accept ride from ${booking.userName} for ₹${booking.fareDetails.totalFare.toStringAsFixed(0)}?',
      confirmText: 'Accept',
      confirmColor: Colors.green,
    );

    if (!confirmed) return;

    final success =
        await ref.read(driverBookingProvider.notifier).acceptBooking(booking.bookingId);

    if (mounted) {
      _showSnackBar(
        success ? 'Booking accepted! Head to pickup location.' : 'Failed to accept booking',
        success ? Colors.green : Colors.red,
      );
    }
  }

  Future<void> _handleReject(Booking booking) async {
    final confirmed = await _showConfirmDialog(
      title: 'Reject Booking',
      message: 'Are you sure you want to reject this booking request?',
      confirmText: 'Reject',
      confirmColor: Colors.red,
    );

    if (!confirmed) return;

    final success =
        await ref.read(driverBookingProvider.notifier).rejectBooking(booking.bookingId);

    if (mounted) {
      _showSnackBar(
        success ? 'Booking rejected' : 'Failed to reject booking',
        success ? Colors.grey : Colors.red,
      );
    }
  }

  Future<void> _handleArrived(Booking booking) async {
    setState(() => _isProcessing = true);

    try {
      final success = await ref
          .read(driverBookingProvider.notifier)
          .arrivedAtPickup(booking.bookingId);

      if (mounted) {
        _showSnackBar(
          success
              ? 'Marked as arrived. Ask customer for OTP to start trip.'
              : 'Failed to update status',
          success ? Colors.blue : Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleStartTrip(Booking booking) async {
    if (_otpInput.length != 4) {
      _showSnackBar('Please enter the 4-digit OTP', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await ref
          .read(driverBookingProvider.notifier)
          .startTrip(booking.bookingId, _otpInput);

      if (mounted) {
        if (success) {
          setState(() => _otpInput = '');
          _showSnackBar('Trip started! Navigate to drop location.', Colors.green);
        } else {
          _showSnackBar('Invalid OTP. Please try again.', Colors.red);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleComplete(Booking booking) async {
    final confirmed = await _showConfirmDialog(
      title: 'Complete Trip',
      message: 'Mark this trip as completed?\nFare: ₹${booking.fareDetails.totalFare.toStringAsFixed(0)}',
      confirmText: 'Complete',
      confirmColor: Colors.green,
    );

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      final success = await ref
          .read(driverBookingProvider.notifier)
          .completeTrip(booking.bookingId);

      if (mounted) {
        _showSnackBar(
          success ? 'Trip completed successfully!' : 'Failed to complete trip',
          success ? Colors.green : Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleNavigate(Booking booking) async {
    final destination = booking.status == BookingStatus.inProgress
        ? booking.dropLocation
        : booking.pickupLocation;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        AppLogger.error('Could not launch maps', tag: 'DriverDashboard');
        if (mounted) {
          _showSnackBar('Could not open navigation', Colors.red);
        }
      }
    } catch (e) {
      AppLogger.error('Navigation error', error: e, tag: 'DriverDashboard');
      if (mounted) {
        _showSnackBar('Could not open navigation', Colors.red);
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
