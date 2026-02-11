import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver_availability.dart';
import '../providers/availability_provider.dart';

class TripPreferencesSection extends ConsumerWidget {
  final String vehicleId;
  final DriverAvailability availability;

  const TripPreferencesSection({
    super.key,
    required this.vehicleId,
    required this.availability,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Trip Type Preferences',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose which types of trips you want to accept',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          _buildTripToggle(
            context,
            ref,
            'Wedding & Special Events',
            'Accept bookings for weddings and special occasions',
            Icons.celebration,
            Colors.purple,
            availability.tripPreferences.weddingBookings.enabled,
            'weddingBookings',  // ✅ FIXED: Changed to match provider case name
            additionalInfo: '1.5x fare multiplier',
          ),

          _buildTripToggle(
            context,
            ref,
            'Long Distance (200+ km)',
            'Trips greater than 200 kilometers',
            Icons.route,
            Colors.orange,
            availability.tripPreferences.longDistance.enabled,
            'longDistance',
            additionalInfo: 'Max ${availability.tripPreferences.longDistance.maxDistance} km',
          ),

          _buildTripToggle(
            context,
            ref,
            'Outstation Trips',
            'Inter-city and outstation journeys',
            Icons.location_city,
            Colors.teal,
            availability.tripPreferences.outstationTrips.enabled,
            'outstationTrips',  // ✅ FIXED: Changed to match provider case name
          ),

          _buildTripToggle(
            context,
            ref,
            'One-Way Trips',
            'Drop-off without return passenger',
            Icons.arrow_forward,
            Colors.blue,
            availability.tripPreferences.oneWayTrip.enabled,
            'oneWayTrip',  // ✅ FIXED: Changed to match provider case name
            additionalInfo: 'Return charges apply',
          ),

          _buildTripToggle(
            context,
            ref,
            'Round Trips',
            'Pick-up and drop-off with return',
            Icons.sync_alt,
            Colors.green,
            availability.tripPreferences.roundTrip.enabled,
            'roundTrip',  // ✅ FIXED: Changed to match provider case name
            additionalInfo: '₹${availability.tripPreferences.roundTrip.waitingCharges}/hr waiting',
          ),

          _buildTripToggle(
            context,
            ref,
            'Weekend Bookings',
            'Saturday and Sunday availability',
            Icons.weekend,
            Colors.indigo,
            availability.tripPreferences.weekendBookings.enabled,
            'weekendBookings',  // ✅ FIXED: Changed to match provider case name
            additionalInfo: '1.2x fare multiplier',
          ),
        ],
      ),
    );
  }

  Widget _buildTripToggle(
      BuildContext context,
      WidgetRef ref,
      String title,
      String subtitle,
      IconData icon,
      Color color,
      bool isEnabled,
      String type, {
        String? additionalInfo,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEnabled ? color.withValues(alpha:0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? color : Colors.grey[300]!,
          width: isEnabled ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled ? color : Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? color : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (additionalInfo != null && isEnabled)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      additionalInfo,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: isEnabled,
              onChanged: (value) {
                // ✅ FIXED: Create proper Map with all required fields
                _updateTripPreference(ref, type, value);
              },
              activeTrackColor: color,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Helper method to properly update trip preferences
  void _updateTripPreference(WidgetRef ref, String type, bool newValue) {
    Map<String, dynamic> updatedConfig;

    switch (type) {
      case 'weddingBookings':
        final current = availability.tripPreferences.weddingBookings;
        updatedConfig = {
          'enabled': newValue,
          'minAdvanceBooking': current.minAdvanceBooking,
          'fareMultiplier': current.fareMultiplier,
        };
        break;

      case 'longDistance':
        final current = availability.tripPreferences.longDistance;
        updatedConfig = {
          'enabled': newValue,
          'maxDistance': current.maxDistance,
          'overnightStay': current.overnightStay,
        };
        break;

      case 'outstationTrips':
        final current = availability.tripPreferences.outstationTrips;
        updatedConfig = {
          'enabled': newValue,
          'minDistance': current.minDistance,
        };
        break;

      case 'oneWayTrip':
        final current = availability.tripPreferences.oneWayTrip;
        updatedConfig = {
          'enabled': newValue,
          'returnCharges': current.returnCharges,
        };
        break;

      case 'roundTrip':
        final current = availability.tripPreferences.roundTrip;
        updatedConfig = {
          'enabled': newValue,
          'waitingCharges': current.waitingCharges,
        };
        break;

      case 'weekendBookings':
        final current = availability.tripPreferences.weekendBookings;
        updatedConfig = {
          'enabled': newValue,
          'fareMultiplier': current.fareMultiplier,
        };
        break;

      default:
        return;
    }

    ref.read(availabilityProvider(vehicleId).notifier)
        .updateTripPreference(type, updatedConfig);
  }
}
