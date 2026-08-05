import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/test_mode.dart';
import '../../core/utils/app_logger.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notification_provider.dart';
import '../../router/routes_name.dart';
import '../../services/booking_service.dart';
import '../../widgets/booking/active_ride_card.dart';
import '../../widgets/booking/driver_stats_card.dart';
import '../../widgets/booking/pending_booking_card.dart';
import '../../widgets/driver/driver_online_toggle.dart';

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

  // OTP brute-force protection lives in the verifyRideOtp Cloud Function;
  // these client-side maps mirror the server lockout so the UI can render a
  // countdown without round-tripping.
  final Map<String, int> _otpFailedAttempts = {};
  final Map<String, DateTime> _otpLockedUntil = {};
  static const int _lockoutMinutes = 5;

  // Agreement cache: vehicleId → signed (true) or not (false).
  // Avoids a Firestore read on every accept tap during the same session.
  final Map<String, bool> _agreementCache = {};

  @override
  void initState() {
    super.initState();
    // Refresh driver data on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverBookingProvider.notifier).loadActiveRide();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        ref.read(notificationProvider.notifier).subscribeAsDriver(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverBookingProvider);
    final pendingRequestsAsync = ref.watch(driverPendingRequestsProvider);
    final statsAsync = ref.watch(driverBookingStatsProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Driver Dashboard',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
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
                child: DriverOnlineStatusCard(userId: uid),
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
                        style: TextStyle(fontFamily: 'Poppins', 
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
                        onCancel: () => _handleDriverCancel(driverState.activeRide!),
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
                      style: TextStyle(fontFamily: 'Poppins', 
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
                                style: TextStyle(fontFamily: 'Poppins', 
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
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests will appear here when customers book nearby.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', 
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
            style: TextStyle(fontFamily: 'Poppins', 
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
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
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

  /// Returns true if the signed-in driver has a signed agreement for [vehicleId].
  /// Result is cached in [_agreementCache] for the lifetime of this widget.
  Future<bool> _hasSignedAgreement(String vehicleId) async {
    if (_agreementCache.containsKey(vehicleId)) {
      return _agreementCache[vehicleId]!;
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection(TestMode.agreementsCollection)
          .doc('${uid}_$vehicleId')
          .get();
      final signed = doc.exists;
      _agreementCache[vehicleId] = signed;
      return signed;
    } catch (e) {
      AppLogger.error('Agreement check failed', tag: 'DriverDashboard', error: e);
      // Fail open on network error — don't silently block the driver.
      return true;
    }
  }

  Future<void> _handleAccept(Booking booking) async {
    final vehicleId = booking.vehicle.vehicleId;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ── Agreement gate ──────────────────────────────────────────────────────
    final signed = await _hasSignedAgreement(vehicleId);
    if (!mounted) return;

    if (!signed) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.description_outlined, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Agreement Required',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'You must sign the Vehicle Owner Agreement for this vehicle before '
            'you can accept bookings.\n\nIt only takes a minute.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now', style: TextStyle(fontFamily: 'Poppins')),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: const Text('Sign Agreement', style: TextStyle(fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Clear cache so the check re-runs after returning
                _agreementCache.remove(vehicleId);
                context.pushNamed(
                  RoutesName.agreementSigning,
                  queryParameters: {'userId': uid, 'vehicleId': vehicleId},
                );
              },
            ),
          ],
        ),
      );
      return; // Do not proceed to accept
    }
    // ── End agreement gate ─────────────────────────────────────────────────

    final confirmed = await _showConfirmDialog(
      title: 'Accept Booking',
      message:
          'Accept ride from ${booking.userName} for ₹${booking.fareDetails.totalFare.toStringAsFixed(0)}?',
      confirmText: 'Accept',
      confirmColor: Colors.green,
    );

    if (!confirmed) return;

    final notifier = ref.read(driverBookingProvider.notifier);
    final success = await notifier.acceptBooking(booking.bookingId);

    if (mounted) {
      _showSnackBar(
        success
            ? 'Booking accepted! Head to pickup location.'
            : ref.read(driverBookingProvider).error ?? 'Failed to accept booking',
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

    final notifier = ref.read(driverBookingProvider.notifier);
    final success = await notifier.rejectBooking(booking.bookingId);

    if (mounted) {
      _showSnackBar(
        success
            ? 'Booking rejected'
            : ref.read(driverBookingProvider).error ?? 'Failed to reject booking',
        success ? Colors.grey : Colors.red,
      );
    }
  }

  Future<void> _handleDriverCancel(Booking booking) async {
    final confirmed = await _showConfirmDialog(
      title: 'Cancel Trip',
      message:
          'Are you sure you want to cancel this trip? The rider will be notified.',
      confirmText: 'Cancel Trip',
      confirmColor: Colors.red,
    );

    if (!confirmed) return;

    final notifier = ref.read(driverBookingProvider.notifier);
    final success = await notifier.cancelAcceptedBooking(booking.bookingId);

    if (mounted) {
      _showSnackBar(
        success
            ? 'Trip cancelled'
            : ref.read(driverBookingProvider).error ?? 'Failed to cancel trip',
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
              : ref.read(driverBookingProvider).error ?? 'Failed to update status',
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
    final bookingId = booking.bookingId;

    // Optimistic client-side lockout for snappy UX. The authoritative lockout
    // lives in the verifyRideOtp Cloud Function (V-04).
    final lockedUntil = _otpLockedUntil[bookingId];
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      final remaining = lockedUntil.difference(DateTime.now()).inSeconds;
      _showSnackBar(
        'Too many wrong attempts. Try again in ${remaining}s.',
        Colors.red,
      );
      return;
    }

    if (_otpInput.length != 6) {
      _showSnackBar('Please enter the 6-digit OTP', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await ref
          .read(driverBookingProvider.notifier)
          .startTrip(bookingId, _otpInput);

      if (!mounted) return;

      if (result.success) {
        _otpFailedAttempts.remove(bookingId);
        _otpLockedUntil.remove(bookingId);
        setState(() => _otpInput = '');
        _showSnackBar('Trip started! Navigate to drop location.', Colors.green);
        return;
      }

      if (result.locked && result.lockedRemainingSeconds != null) {
        _otpLockedUntil[bookingId] = DateTime.now()
            .add(Duration(seconds: result.lockedRemainingSeconds!));
        _otpFailedAttempts.remove(bookingId);
        _showSnackBar(
          'OTP locked. Try again in ${result.lockedRemainingSeconds}s.',
          Colors.red,
        );
        return;
      }

      if (result.invalidOtp) {
        if (result.locked) {
          _otpLockedUntil[bookingId] =
              DateTime.now().add(Duration(minutes: _lockoutMinutes));
          _otpFailedAttempts.remove(bookingId);
          _showSnackBar(
            'OTP locked for $_lockoutMinutes minutes after too many failed attempts.',
            Colors.red,
          );
        } else {
          final remaining = result.attemptsRemaining;
          _showSnackBar(
            remaining != null
                ? 'Invalid OTP. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
                : 'Invalid OTP. Please try again.',
            Colors.red,
          );
        }
        return;
      }

      _showSnackBar(
        result.errorMessage ?? 'Could not verify OTP. Try again.',
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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

      if (!mounted) return;

      if (success) {
        _showSnackBar('Trip completed!', Colors.green);
        // Immediately prompt for cash collection
        await _showPaymentRecordDialog(booking);
      } else {
        _showSnackBar(
          ref.read(driverBookingProvider).error ?? 'Failed to complete trip',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showPaymentRecordDialog(Booking booking) async {
    final totalFare = booking.fareDetails.totalFare;
    final controller = TextEditingController(
      text: totalFare.toStringAsFixed(0),
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Record Cash Received',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _paymentRow('Final fare', '₹${totalFare.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            const Text(
              'Amount received (₹)',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              final result = await ref
                  .read(driverBookingProvider.notifier)
                  .recordPaymentReceived(booking.bookingId, amount);
              if (mounted) {
                result.when(
                  success: (_) => _showSnackBar('Payment recorded: ₹${amount.toStringAsFixed(0)}', Colors.green),
                  failure: (e) => _showSnackBar('Could not record payment: ${e.message}', Colors.red),
                );
              }
            },
            child: const Text('Record', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Widget _paymentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
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
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
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
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
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
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
