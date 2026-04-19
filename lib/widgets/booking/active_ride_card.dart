import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';

/// Card widget for displaying the driver's active ride
class ActiveRideCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onArrived;
  final VoidCallback? onStartTrip;
  final VoidCallback? onComplete;
  final VoidCallback? onNavigate;
  final bool isLoading;
  final String? otpInput;
  final ValueChanged<String>? onOtpChanged;

  const ActiveRideCard({
    super.key,
    required this.booking,
    this.onArrived,
    this.onStartTrip,
    this.onComplete,
    this.onNavigate,
    this.isLoading = false,
    this.otpInput,
    this.onOtpChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getStatusColor().shade600,
            _getStatusColor().shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Ride',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        _getStatusText(),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fare
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${booking.fareDetails.totalFare.toStringAsFixed(0)}',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor().shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User info card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        booking.userName.isNotEmpty
                            ? booking.userName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.userName,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                booking.userPhone,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Call button
                    IconButton(
                      onPressed: () => _callUser(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: Icon(
                        Icons.phone,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Locations
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 30,
                          color: Colors.grey.shade300,
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.pickupLocation.shortAddress,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            booking.dropLocation.shortAddress,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // OTP input (when arrived)
          if (booking.status == BookingStatus.arrived && onOtpChanged != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Enter OTP:',
                      style: TextStyle(fontFamily: 'Poppins', 
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: onOtpChanged,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Poppins', 
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '----',
                          hintStyle: TextStyle(fontFamily: 'Poppins', 
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                // Navigate button
                if (onNavigate != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onNavigate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.navigation),
                      label: Text(
                        'Navigate',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (onNavigate != null) const SizedBox(width: 12),
                // Main action button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _getMainAction(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _getStatusColor().shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: _getStatusColor(),
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getMainActionIcon()),
                              const SizedBox(width: 8),
                              Text(
                                _getMainActionText(),
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MaterialColor _getStatusColor() {
    switch (booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.driverArriving:
        return Colors.blue;
      case BookingStatus.arrived:
        return Colors.orange;
      case BookingStatus.inProgress:
        return Colors.green;
      default:
        return Colors.deepPurple;
    }
  }

  IconData _getStatusIcon() {
    switch (booking.status) {
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.driverArriving:
        return Icons.directions_car;
      case BookingStatus.arrived:
        return Icons.location_on;
      case BookingStatus.inProgress:
        return Icons.navigation;
      default:
        return Icons.local_taxi;
    }
  }

  String _getStatusText() {
    switch (booking.status) {
      case BookingStatus.confirmed:
        return 'Go to Pickup';
      case BookingStatus.driverArriving:
        return 'En Route';
      case BookingStatus.arrived:
        return 'Waiting for Passenger';
      case BookingStatus.inProgress:
        return 'Trip in Progress';
      default:
        return booking.status.displayName;
    }
  }

  VoidCallback? _getMainAction() {
    switch (booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.driverArriving:
        return onArrived;
      case BookingStatus.arrived:
        return onStartTrip;
      case BookingStatus.inProgress:
        return onComplete;
      default:
        return null;
    }
  }

  IconData _getMainActionIcon() {
    switch (booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.driverArriving:
        return Icons.location_on;
      case BookingStatus.arrived:
        return Icons.play_arrow;
      case BookingStatus.inProgress:
        return Icons.flag;
      default:
        return Icons.check;
    }
  }

  String _getMainActionText() {
    switch (booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.driverArriving:
        return "I've Arrived";
      case BookingStatus.arrived:
        return 'Start Trip';
      case BookingStatus.inProgress:
        return 'Complete Trip';
      default:
        return 'Continue';
    }
  }

  void _callUser() async {
    final phone = booking.userPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
