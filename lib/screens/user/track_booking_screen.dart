import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';
import '../../models/driver_location_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/live_location_provider.dart';
import '../../utils/fare_calculator.dart';

class TrackBookingScreen extends ConsumerStatefulWidget {
  final String? bookingId;

  const TrackBookingScreen({super.key, this.bookingId});

  @override
  ConsumerState<TrackBookingScreen> createState() => _TrackBookingScreenState();
}

class _TrackBookingScreenState extends ConsumerState<TrackBookingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the active booking stream for real-time updates
    final bookingAsync = widget.bookingId != null
        ? ref.watch(bookingStreamProvider(widget.bookingId!))
        : ref.watch(activeBookingStreamProvider);

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
            child: bookingAsync.when(
              data: (booking) {
                if (booking == null) {
                  return _buildNoActiveBooking();
                }
                return _buildBookingContent(booking);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, stack) => _buildError(error.toString()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoActiveBooking() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 80,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Booking',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You don\'t have any active rides.\nBook a ride to get started!',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/user-dashboard'),
              icon: const Icon(Icons.home),
              label: Text(
                'Go to Dashboard',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingContent(Booking booking) {
    return Column(
      children: [
        _buildAppBar(booking),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(booking),
                const SizedBox(height: 20),
                _buildMapPlaceholder(booking),
                const SizedBox(height: 20),
                _buildDriverCard(booking),
                const SizedBox(height: 20),
                _buildTripDetails(booking),
                const SizedBox(height: 20),
                _buildTrackingTimeline(booking),
                const SizedBox(height: 20),
                if (booking.status == BookingStatus.arrived ||
                    booking.status == BookingStatus.confirmed)
                  _buildOTPCard(booking),
                if (booking.isCompleted && booking.canRate)
                  _buildRatingCard(booking),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        if (booking.isActive) _buildBottomActions(booking),
      ],
    );
  }

  Widget _buildAppBar(Booking booking) {
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
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Booking',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '#${booking.bookingId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _shareTrip(booking),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Booking booking) {
    final statusInfo = _getStatusInfo(booking.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo.color, statusInfo.color.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusInfo.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo.title,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusInfo.subtitle,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (booking.estimatedArrival != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                booking.estimatedArrival!,
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusInfo.color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(Booking booking) {
    // Watch driver location stream when trip is active
    final showLiveLocation = booking.status == BookingStatus.driverArriving ||
        booking.status == BookingStatus.arrived ||
        booking.status == BookingStatus.inProgress;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: showLiveLocation
          ? _buildLiveLocationCard(booking)
          : _buildStaticMapPlaceholder(booking),
    );
  }

  Widget _buildLiveLocationCard(Booking booking) {
    final locationAsync = ref.watch(driverLocationStreamProvider(booking.bookingId));

    return locationAsync.when(
      data: (location) {
        if (location == null) {
          return _buildWaitingForLocation();
        }
        return _buildLocationDisplay(booking, location);
      },
      loading: () => _buildWaitingForLocation(),
      error: (e, s) => _buildStaticMapPlaceholder(booking),
    );
  }

  Widget _buildWaitingForLocation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Getting driver location...',
            style: TextStyle(fontFamily: 'Poppins', 
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplay(Booking booking, DriverLocationData location) {
    return Stack(
      children: [
        // Location info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      location.isMoving ? Icons.directions_car : Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Location',
                          style: TextStyle(fontFamily: 'Poppins', 
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          location.isStale ? 'Last updated' : 'Live',
                          style: TextStyle(fontFamily: 'Poppins', 
                            color: location.isStale
                                ? Colors.orange.shade300
                                : Colors.green.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Live indicator
                  if (!location.isStale)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(fontFamily: 'Poppins', 
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Speed and status
              Row(
                children: [
                  _buildLocationChip(
                    icon: Icons.speed,
                    label: location.formattedSpeed,
                  ),
                  const SizedBox(width: 12),
                  _buildLocationChip(
                    icon: location.isMoving ? Icons.trending_up : Icons.pause,
                    label: location.isMoving ? 'Moving' : 'Stationary',
                  ),
                ],
              ),
            ],
          ),
        ),
        // Open in Maps button
        Positioned(
          bottom: 12,
          right: 12,
          child: ElevatedButton.icon(
            onPressed: () => _openInMaps(location, booking),
            icon: const Icon(Icons.navigation, size: 18),
            label: Text('View in Maps', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', 
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticMapPlaceholder(Booking booking) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map,
                  size: 48, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'Live tracking map',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: ElevatedButton.icon(
            onPressed: () => _openTripInMaps(booking),
            icon: const Icon(Icons.fullscreen, size: 18),
            label: Text('View Route', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openInMaps(DriverLocationData location, Booking booking) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTripInMaps(Booking booking) async {
    final origin = '${booking.pickupLocation.latitude},${booking.pickupLocation.longitude}';
    final destination = '${booking.dropLocation.latitude},${booking.dropLocation.longitude}';
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDriverCard(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                backgroundImage: booking.driver.photoUrl != null
                    ? NetworkImage(booking.driver.photoUrl!)
                    : null,
                child: booking.driver.photoUrl == null
                    ? Text(
                        booking.driver.name[0].toUpperCase(),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.driver.name,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          booking.driver.rating.toStringAsFixed(1),
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          booking.vehicle.registrationNumber,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${booking.vehicle.brand} ${booking.vehicle.model}',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  color: Colors.green,
                  onTap: () => _callDriver(booking.driver.phoneNumber),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.message,
                  label: 'Message',
                  color: Colors.blue,
                  onTap: () => _messageDriver(booking.driver.phoneNumber),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontFamily: 'Poppins', 
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetails(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.circle,
            iconColor: Colors.green,
            label: 'Pickup',
            value: booking.pickupLocation.address,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Column(
                  children: List.generate(
                    3,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      width: 2,
                      height: 6,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            label: 'Drop',
            value: booking.dropLocation.address,
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(
                Icons.straighten,
                '${booking.estimatedDistance?.toStringAsFixed(1) ?? "0"} km',
              ),
              _buildInfoChip(
                Icons.access_time,
                '${booking.estimatedDuration ?? 0} min',
              ),
              _buildInfoChip(
                Icons.currency_rupee,
                FareCalculator.formatFare(booking.fareDetails.totalFare),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              Text(
                value,
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 14,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontFamily: 'Poppins', 
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(Booking booking) {
    final steps = _getTrackingSteps(booking);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Progress',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            return _buildTimelineItem(
              title: step['title'] as String,
              time: step['time'] as String,
              completed: step['completed'] as bool,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getTrackingSteps(Booking booking) {
    final statusIndex = _getStatusIndex(booking.status);

    return [
      {
        'title': 'Booking Confirmed',
        'time': _formatTime(booking.createdAt),
        'completed': statusIndex >= 0,
      },
      {
        'title': 'Driver Assigned',
        'time': _formatTime(booking.confirmedAt),
        'completed': statusIndex >= 1,
      },
      {
        'title': 'Driver En Route',
        'time': statusIndex >= 2 ? 'On the way' : '',
        'completed': statusIndex >= 2,
      },
      {
        'title': 'Driver Arrived',
        'time': statusIndex >= 3 ? 'At pickup' : '',
        'completed': statusIndex >= 3,
      },
      {
        'title': 'Trip Started',
        'time': _formatTime(booking.startedAt),
        'completed': statusIndex >= 4,
      },
      {
        'title': 'Trip Completed',
        'time': _formatTime(booking.completedAt),
        'completed': statusIndex >= 5,
      },
    ];
  }

  int _getStatusIndex(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 0;
      case BookingStatus.confirmed:
        return 1;
      case BookingStatus.driverArriving:
        return 2;
      case BookingStatus.arrived:
        return 3;
      case BookingStatus.inProgress:
        return 4;
      case BookingStatus.completed:
        return 5;
      default:
        return -1;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  Widget _buildTimelineItem({
    required String title,
    required String time,
    required bool completed,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? Colors.green : Colors.white24,
              ),
              child: completed
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: completed ? Colors.green : Colors.white24,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 14,
                    color: completed ? Colors.white : Colors.white54,
                    fontWeight: completed ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPCard(Booking booking) {
    if (booking.rideOtp == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade600,
            Colors.orange.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share OTP with driver to start ride',
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.rideOtp!,
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.notifications_outlined, color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Also sent as a push notification',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Rate your ride',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => _showRatingDialog(booking, index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.star_outline,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade800,
            Colors.deepPurple.shade900,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (booking.canCancel)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showCancelDialog(booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Cancel Ride',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (booking.canCancel) const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleEmergency(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emergency, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SOS',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  _StatusInfo _getStatusInfo(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return _StatusInfo(
          'Finding Driver',
          'Looking for available drivers nearby',
          Icons.search,
          Colors.orange,
        );
      case BookingStatus.confirmed:
        return _StatusInfo(
          'Driver Assigned',
          'Your driver is preparing to pick you up',
          Icons.person,
          Colors.blue,
        );
      case BookingStatus.driverArriving:
        return _StatusInfo(
          'Driver On The Way',
          'Your driver is heading to pickup location',
          Icons.directions_car,
          Colors.green,
        );
      case BookingStatus.arrived:
        return _StatusInfo(
          'Driver Arrived',
          'Share OTP to start your trip',
          Icons.location_on,
          Colors.green,
        );
      case BookingStatus.inProgress:
        return _StatusInfo(
          'Trip In Progress',
          'Enjoy your ride!',
          Icons.navigation,
          Colors.green,
        );
      case BookingStatus.completed:
        return _StatusInfo(
          'Trip Completed',
          'Thank you for riding with us!',
          Icons.check_circle,
          Colors.green,
        );
      case BookingStatus.cancelled:
        return _StatusInfo(
          'Booking Cancelled',
          'This booking has been cancelled',
          Icons.cancel,
          Colors.red,
        );
      default:
        return _StatusInfo(
          'Unknown Status',
          '',
          Icons.help,
          Colors.grey,
        );
    }
  }

  Future<void> _callDriver(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number not available',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _messageDriver(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number not available',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.parse('sms:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _shareTrip(Booking booking) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share feature coming soon',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
      ),
    );
  }

  void _handleEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Emergency SOS',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will alert emergency contacts and share your live location. Continue?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Trigger SOS
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Emergency contacts notified',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Call Emergency',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(Booking booking) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Ride?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to cancel this ride? Cancellation charges may apply.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'No, Keep Ride',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref
                  .read(bookingProvider.notifier)
                  .cancelBooking(reason: 'Cancelled by user');

              if (success) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Booking cancelled',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                context.go('/user-dashboard');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Yes, Cancel',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(Booking booking, int initialRating) {
    int rating = initialRating;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Rate Your Ride',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        rating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < rating ? Icons.star : Icons.star_outline,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Skip',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await ref
                    .read(bookingProvider.notifier)
                    .rateBooking(
                      booking.bookingId,
                      rating.toDouble(),
                      review: reviewController.text.isNotEmpty
                          ? reviewController.text
                          : null,
                    );

                if (success) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Thank you for your feedback!',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Submit',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _StatusInfo(this.title, this.subtitle, this.icon, this.color);
}
