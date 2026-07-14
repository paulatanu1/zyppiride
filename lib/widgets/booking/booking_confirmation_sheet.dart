import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/available_vehicle_model.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../utils/fare_calculator.dart';

/// Bottom sheet for confirming booking with fare breakdown
class BookingConfirmationSheet extends ConsumerStatefulWidget {
  final AvailableVehicle vehicle;
  final FareEstimate fare;
  final BookingLocation pickupLocation;
  final BookingLocation dropLocation;
  final BookingType bookingType;
  final double estimatedDistance;
  final int estimatedDuration;
  final Function(Booking booking)? onBookingCreated;

  const BookingConfirmationSheet({
    super.key,
    required this.vehicle,
    required this.fare,
    required this.pickupLocation,
    required this.dropLocation,
    required this.bookingType,
    required this.estimatedDistance,
    required this.estimatedDuration,
    this.onBookingCreated,
  });

  @override
  ConsumerState<BookingConfirmationSheet> createState() =>
      _BookingConfirmationSheetState();
}

class _BookingConfirmationSheetState
    extends ConsumerState<BookingConfirmationSheet> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  // Promo entry UI is hidden until backend validation exists (v2) — the
  // previous stub faked a 10% discount. Fields remain for fare plumbing.
  final String? _promoCode = null;
  final double _promoDiscount = 0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Confirm Booking',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver & Vehicle info
                  _buildDriverVehicleCard(),
                  const SizedBox(height: 20),

                  // Route info
                  _buildRouteCard(),
                  const SizedBox(height: 20),

                  // Fare breakdown
                  _buildFareBreakdown(),
                  const SizedBox(height: 20),

                  // Payment method
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 20),

                  // Error message
                  if (bookingState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bookingState.error!,
                              style: TextStyle(fontFamily: 'Poppins', 
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Fare',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _getFinalFare(),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: bookingState.isCreating ? null : _confirmBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.deepPurple.shade200,
                      ),
                      child: bookingState.isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Confirm Booking',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverVehicleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Driver photo or vehicle image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.vehicle.driverPhotoUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.vehicle.driverPhotoUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildPlaceholderImage(),
                    errorWidget: (context, url, error) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          const SizedBox(width: 16),

          // Driver & vehicle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicle.driverName,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.vehicle.vehicleInfo.displayName,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      widget.vehicle.driverRating.toStringAsFixed(1),
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${widget.vehicle.totalTrips} trips',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vehicle number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.vehicle.vehicleInfo.registrationNumber,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person,
        color: Colors.grey.shade400,
        size: 30,
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.circle, color: Colors.green.shade600, size: 12),
                  Container(
                    width: 2,
                    height: 30,
                    color: Colors.grey.shade400,
                  ),
                  Icon(Icons.location_on, color: Colors.red.shade600, size: 16),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      widget.pickupLocation.address,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Drop',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      widget.dropLocation.address,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
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
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTripInfo(
                Icons.straighten,
                '${widget.estimatedDistance.toStringAsFixed(1)} km',
                'Distance',
              ),
              _buildTripInfo(
                Icons.access_time,
                '${widget.estimatedDuration} min',
                'Duration',
              ),
              _buildTripInfo(
                Icons.category,
                widget.bookingType.displayName,
                'Type',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFareBreakdown() {
    final fareDetails = FareDetails.calculate(
      baseFare: widget.vehicle.pricing.basePrice,
      perKmRate: widget.vehicle.pricing.perKmRate,
      distanceKm: widget.estimatedDistance,
      promoCode: _promoCode,
      promoDiscount: _promoDiscount,
    );

    final breakdownItems = FareCalculator.getFareBreakdown(fareDetails);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fare Breakdown',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...breakdownItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        color: item.isDiscount
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      item.formattedAmount,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: item.isDiscount
                            ? Colors.green.shade700
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PaymentMethod.values.map((method) {
              final isSelected = _selectedPaymentMethod == method;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = method;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurple : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isSelected ? Colors.deepPurple : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPaymentIcon(method),
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        method.displayName,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.upi:
        return Icons.qr_code;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.wallet:
        return Icons.account_balance_wallet;
      case PaymentMethod.netBanking:
        return Icons.account_balance;
    }
  }

  String _getFinalFare() {
    final fareDetails = FareDetails.calculate(
      baseFare: widget.vehicle.pricing.basePrice,
      perKmRate: widget.vehicle.pricing.perKmRate,
      distanceKm: widget.estimatedDistance,
      promoCode: _promoCode,
      promoDiscount: _promoDiscount,
    );
    return FareCalculator.formatFare(fareDetails.totalFare);
  }

  Future<void> _confirmBooking() async {
    final booking = await ref.read(bookingProvider.notifier).createBooking(
          bookingType: widget.bookingType,
          pickupLocation: widget.pickupLocation,
          dropLocation: widget.dropLocation,
          vehicle: widget.vehicle,
          estimatedDistance: widget.estimatedDistance,
          estimatedDuration: widget.estimatedDuration,
          paymentMethod: _selectedPaymentMethod,
          promoCode: _promoCode,
        );

    if (booking != null && mounted) {
      Navigator.pop(context); // Close confirmation sheet
      Navigator.pop(context); // Close vehicle selection sheet
      widget.onBookingCreated?.call(booking);
    }
  }
}

/// Show booking confirmation bottom sheet
Future<void> showBookingConfirmationSheet(
  BuildContext context, {
  required AvailableVehicle vehicle,
  required FareEstimate fare,
  required BookingLocation pickupLocation,
  required BookingLocation dropLocation,
  required BookingType bookingType,
  required double estimatedDistance,
  required int estimatedDuration,
  Function(Booking booking)? onBookingCreated,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BookingConfirmationSheet(
      vehicle: vehicle,
      fare: fare,
      pickupLocation: pickupLocation,
      dropLocation: dropLocation,
      bookingType: bookingType,
      estimatedDistance: estimatedDistance,
      estimatedDuration: estimatedDuration,
      onBookingCreated: onBookingCreated,
    ),
  );
}
