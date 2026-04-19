import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/available_vehicle_model.dart';
import '../../providers/vehicle_search_provider.dart';
import '../../utils/fare_calculator.dart';

/// Bottom sheet for selecting a vehicle after search
class VehicleSelectionSheet extends ConsumerStatefulWidget {
  final String pickupAddress;
  final String dropAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final String? vehicleType;
  final double estimatedDistance;
  final int estimatedDuration;
  final Function(AvailableVehicle vehicle, FareEstimate fare) onVehicleSelected;

  const VehicleSelectionSheet({
    super.key,
    required this.pickupAddress,
    required this.dropAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.vehicleType,
    required this.estimatedDistance,
    required this.estimatedDuration,
    required this.onVehicleSelected,
  });

  @override
  ConsumerState<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends ConsumerState<VehicleSelectionSheet> {
  AvailableVehicle? _selectedVehicle;
  FareEstimate? _selectedFare;

  @override
  void initState() {
    super.initState();
    _searchVehicles();
  }

  void _searchVehicles() {
    // Update filters to trigger search
    final notifier = ref.read(vehicleFiltersProvider.notifier);
    notifier.clearAllFilters();
    if (widget.vehicleType != null) {
      notifier.updateVehicleType(widget.vehicleType);
    }
    // The vehicleSearchProvider will auto-search when filters change
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(vehicleSearchProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Your Ride',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRouteInfo(),
              ],
            ),
          ),

          const Divider(height: 1),

          // Vehicle list
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchState.error != null
                    ? _buildError(searchState.error!)
                    : searchState.vehicles.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: searchState.vehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = searchState.vehicles[index];
                              final fare = FareCalculator.getEstimate(
                                pricing: vehicle.pricing,
                                distanceKm: widget.estimatedDistance,
                                estimatedDurationMinutes: widget.estimatedDuration,
                              );
                              return _buildVehicleCard(vehicle, fare);
                            },
                          ),
          ),

          // Confirm button
          if (_selectedVehicle != null)
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFare?.formattedRange ?? '',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            '${_selectedVehicle!.vehicleInfo.displayName} • ${widget.estimatedDuration} mins',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.onVehicleSelected(_selectedVehicle!, _selectedFare!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Confirm',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontWeight: FontWeight.w600,
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

  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Icon(Icons.circle, color: Colors.green.shade600, size: 12),
              Container(
                width: 2,
                height: 20,
                color: Colors.grey.shade400,
              ),
              Icon(Icons.location_on, color: Colors.red.shade600, size: 16),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pickupAddress,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.dropAddress,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.estimatedDistance.toStringAsFixed(1)} km',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
              Text(
                '${widget.estimatedDuration} min',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(AvailableVehicle vehicle, FareEstimate fare) {
    final isSelected = _selectedVehicle?.id == vehicle.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicle = vehicle;
          _selectedFare = fare;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Vehicle image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: vehicle.vehicleImages.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: vehicle.vehicleImages.first,
                      width: 80,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.directions_car),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.directions_car),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getVehicleIcon(vehicle.vehicleInfo.type),
                        color: Colors.grey.shade600,
                        size: 32,
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Vehicle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        vehicle.vehicleInfo.displayName,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (vehicle.vehicleInfo.hasAC) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AC',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.driverRating.toStringAsFixed(1),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people, color: Colors.grey.shade600, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${vehicle.vehicleInfo.seatingCapacity}',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle.driverName,
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fare.formattedRange,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  '₹${vehicle.pricing.perKmRate.toStringAsFixed(0)}/km',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            // Selection indicator
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: Colors.deepPurple,
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Unable to find rides',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _searchVehicles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No rides available',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No vehicles found in your area.\nPlease try again later.',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.electric_rickshaw;
      case 'suv':
        return Icons.airport_shuttle;
      case 'premium':
        return Icons.local_taxi;
      default:
        return Icons.directions_car;
    }
  }
}

/// Show vehicle selection bottom sheet
Future<void> showVehicleSelectionSheet(
  BuildContext context, {
  required String pickupAddress,
  required String dropAddress,
  double? pickupLat,
  double? pickupLng,
  double? dropLat,
  double? dropLng,
  String? vehicleType,
  required double estimatedDistance,
  required int estimatedDuration,
  required Function(AvailableVehicle vehicle, FareEstimate fare) onVehicleSelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => VehicleSelectionSheet(
      pickupAddress: pickupAddress,
      dropAddress: dropAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropLat: dropLat,
      dropLng: dropLng,
      vehicleType: vehicleType,
      estimatedDistance: estimatedDistance,
      estimatedDuration: estimatedDuration,
      onVehicleSelected: onVehicleSelected,
    ),
  );
}
