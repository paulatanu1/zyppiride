import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../models/available_vehicle_model.dart';
import '../../providers/vehicle_search_provider.dart';
import '../../providers/location_provider.dart';

class ReserveVehicleScreen extends ConsumerStatefulWidget {
  const ReserveVehicleScreen({super.key});

  @override
  ConsumerState<ReserveVehicleScreen> createState() => _ReserveVehicleScreenState();
}

class _ReserveVehicleScreenState extends ConsumerState<ReserveVehicleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _scrollController.addListener(_onScroll);

    // Apply user's location as default filter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyUserLocationFilter();
    });
  }

  void _applyUserLocationFilter() {
    final locationState = ref.read(locationProvider);
    if (locationState.hasLocation && locationState.location!.city != null) {
      ref.read(vehicleFiltersProvider.notifier).updateCity(locationState.location!.city);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(vehicleSearchProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(vehicleSearchProvider);
    final filters = ref.watch(vehicleFiltersProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/user-dashboard');
            }
          },
        ),
        title: Text(
          'Reserve Vehicle',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list, color: Colors.white, size: 22),
                ),
                if (filters.activeFilterCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${filters.activeFilterCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade500,
              Colors.deepPurple.shade300,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Active Filters Chips
                if (filters.hasActiveFilters) _buildActiveFiltersChips(filters),

                // Search Results
                Expanded(
                  child: searchState.isLoading && searchState.vehicles.isEmpty
                      ? _buildLoadingState()
                      : searchState.error != null && searchState.vehicles.isEmpty
                          ? _buildErrorState(searchState.error!)
                          : searchState.vehicles.isEmpty
                              ? _buildEmptyState()
                              : _buildVehicleList(searchState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersChips(VehicleSearchFilters filters) {
    final chips = <Widget>[];

    if (filters.vehicleType != null) {
      chips.add(_buildFilterChip(
        label: _formatVehicleType(filters.vehicleType!),
        onRemove: () => ref.read(vehicleFiltersProvider.notifier).clearFilter('vehicleType'),
      ));
    }
    if (filters.city != null) {
      chips.add(_buildFilterChip(
        label: filters.city!,
        onRemove: () => ref.read(vehicleFiltersProvider.notifier).clearFilter('city'),
      ));
    }
    if (filters.hasAC != null) {
      chips.add(_buildFilterChip(
        label: filters.hasAC! ? 'AC' : 'Non-AC',
        onRemove: () => ref.read(vehicleFiltersProvider.notifier).clearFilter('hasAC'),
      ));
    }
    if (filters.fuelType != null) {
      chips.add(_buildFilterChip(
        label: _formatFuelType(filters.fuelType!),
        onRemove: () => ref.read(vehicleFiltersProvider.notifier).clearFilter('fuelType'),
      ));
    }
    if (filters.transmission != null) {
      chips.add(_buildFilterChip(
        label: _formatTransmission(filters.transmission!),
        onRemove: () => ref.read(vehicleFiltersProvider.notifier).clearFilter('transmission'),
      ));
    }
    if (filters.minSeats != null) {
      chips.add(_buildFilterChip(
        label: '${filters.minSeats}+ Seats',
        onRemove: () => ref.read(vehicleFiltersProvider.notifier).clearFilter('minSeats'),
      ));
    }
    if (filters.minPrice != null || filters.maxPrice != null) {
      final priceLabel = filters.minPrice != null && filters.maxPrice != null
          ? '₹${filters.minPrice!.toInt()}-${filters.maxPrice!.toInt()}/km'
          : filters.minPrice != null
              ? '₹${filters.minPrice!.toInt()}+/km'
              : '≤₹${filters.maxPrice!.toInt()}/km';
      chips.add(_buildFilterChip(
        label: priceLabel,
        onRemove: () {
          ref.read(vehicleFiltersProvider.notifier).updatePriceRange(null, null);
        },
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Filters',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              TextButton(
                onPressed: () => ref.read(vehicleFiltersProvider.notifier).clearAllFilters(),
                child: Text(
                  'Clear All',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onRemove}) {
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Finding vehicles...',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(vehicleSearchProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Try Again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined, size: 64, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Text(
              'No vehicles found',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters to find more vehicles',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(vehicleFiltersProvider.notifier).clearAllFilters(),
              icon: const Icon(Icons.filter_alt_off),
              label: Text(
                'Clear Filters',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildVehicleList(VehicleSearchState searchState) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(vehicleSearchProvider.notifier).refresh();
      },
      color: Colors.deepPurple,
      backgroundColor: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: searchState.vehicles.length + (searchState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= searchState.vehicles.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          return _buildVehicleCard(searchState.vehicles[index]);
        },
      ),
    );
  }

  Widget _buildVehicleCard(AvailableVehicle vehicle) {
    return GestureDetector(
      onTap: () => _viewVehicleDetails(vehicle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Image
              if (vehicle.vehicleImages.isNotEmpty)
                Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        image: DecorationImage(
                          image: NetworkImage(vehicle.vehicleImages.first),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: vehicle.isAvailable ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          vehicle.isAvailable ? 'Available' : 'Busy',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              vehicle.driverRating.toStringAsFixed(1),
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Colors.white38,
                  ),
                ),

              // Vehicle Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Name & Type
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle.vehicleInfo.displayName,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_formatVehicleType(vehicle.vehicleInfo.type)} • ${vehicle.vehicleInfo.year}',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${vehicle.pricing.perKmRate.toInt()}',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'per km',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Features Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFeatureChip(
                          icon: Icons.airline_seat_recline_normal,
                          label: '${vehicle.vehicleInfo.seatingCapacity} Seats',
                        ),
                        _buildFeatureChip(
                          icon: vehicle.vehicleInfo.hasAC ? Icons.ac_unit : Icons.air,
                          label: vehicle.vehicleInfo.hasAC ? 'AC' : 'Non-AC',
                        ),
                        _buildFeatureChip(
                          icon: Icons.local_gas_station,
                          label: _formatFuelType(vehicle.vehicleInfo.fuelType),
                        ),
                        _buildFeatureChip(
                          icon: Icons.settings,
                          label: _formatTransmission(vehicle.vehicleInfo.transmission),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Driver Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white24,
                          backgroundImage: vehicle.driverPhotoUrl != null
                              ? NetworkImage(vehicle.driverPhotoUrl!)
                              : null,
                          child: vehicle.driverPhotoUrl == null
                              ? const Icon(Icons.person, color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle.driverName,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${vehicle.totalTrips} trips • ${vehicle.location.displayLocation}',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Book Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: vehicle.isAvailable
                            ? () => _onBookVehicle(vehicle)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          disabledBackgroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          vehicle.isAvailable ? 'Book Now' : 'Not Available',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
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
      ),
    );
  }

  Widget _buildFeatureChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _onBookVehicle(AvailableVehicle vehicle) {
    _viewVehicleDetails(vehicle);
  }

  void _viewVehicleDetails(AvailableVehicle vehicle) {
    ref.read(selectedVehicleProvider.notifier).state = vehicle;
    context.push('/vehicle-details');
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FilterBottomSheet(),
    );
  }

  String _formatVehicleType(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return 'Car';
      case 'suv':
        return 'SUV';
      case 'sedan':
        return 'Sedan';
      case 'hatchback':
        return 'Hatchback';
      case 'bike':
        return 'Bike';
      case 'auto':
        return 'Auto';
      case 'tempo':
        return 'Tempo';
      case 'truck':
        return 'Truck';
      default:
        return type;
    }
  }

  String _formatFuelType(String fuelType) {
    switch (fuelType.toLowerCase()) {
      case 'petrol':
        return 'Petrol';
      case 'diesel':
        return 'Diesel';
      case 'electric':
        return 'Electric';
      case 'cng':
        return 'CNG';
      case 'hybrid':
        return 'Hybrid';
      default:
        return fuelType;
    }
  }

  String _formatTransmission(String transmission) {
    switch (transmission.toLowerCase()) {
      case 'manual':
        return 'Manual';
      case 'automatic':
        return 'Automatic';
      case 'amt':
        return 'AMT';
      default:
        return transmission;
    }
  }
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  const _FilterBottomSheet();

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  late String? _selectedVehicleType;
  late String? _selectedCity;
  late String? _selectedFuelType;
  late String? _selectedTransmission;
  late bool? _selectedHasAC;
  late int? _selectedMinSeats;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(vehicleFiltersProvider);
    _selectedVehicleType = filters.vehicleType;
    _selectedCity = filters.city;
    _selectedFuelType = filters.fuelType;
    _selectedTransmission = filters.transmission;
    _selectedHasAC = filters.hasAC;
    _selectedMinSeats = filters.minSeats;
    _priceRange = RangeValues(
      filters.minPrice ?? 5,
      filters.maxPrice ?? 50,
    );
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(availableCitiesProvider);
    final vehicleTypesAsync = ref.watch(availableVehicleTypesProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade800,
            Colors.deepPurple.shade600,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: _resetFilters,
                      child: Text(
                        'Reset',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Vehicle Type
                    _buildSectionTitle('Vehicle Type'),
                    vehicleTypesAsync.when(
                      data: (types) => _buildChipSelector(
                        items: {'car', 'suv', 'sedan', 'hatchback', 'bike', 'auto', ...types}.toList(),
                        selected: _selectedVehicleType,
                        onSelected: (value) => setState(() => _selectedVehicleType = value),
                        labelBuilder: (item) => _formatType(item),
                      ),
                      loading: () => const CircularProgressIndicator(color: Colors.white),
                      error: (e, s) => _buildChipSelector(
                        items: const ['car', 'suv', 'sedan', 'hatchback', 'bike', 'auto'],
                        selected: _selectedVehicleType,
                        onSelected: (value) => setState(() => _selectedVehicleType = value),
                        labelBuilder: (item) => _formatType(item),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // City
                    _buildSectionTitle('City'),
                    citiesAsync.when(
                      data: (cities) => cities.isEmpty
                          ? Text(
                              'No cities available',
                              style: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                            )
                          : _buildChipSelector(
                              items: cities,
                              selected: _selectedCity,
                              onSelected: (value) => setState(() => _selectedCity = value),
                              labelBuilder: (item) => item,
                            ),
                      loading: () => const CircularProgressIndicator(color: Colors.white),
                      error: (e, s) => Text(
                        'Failed to load cities',
                        style: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Price Range
                    _buildSectionTitle('Price Range (₹/km)'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${_priceRange.start.toInt()}',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '₹${_priceRange.end.toInt()}',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: RangeSlider(
                        values: _priceRange,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        onChanged: (values) => setState(() => _priceRange = values),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Seating Capacity
                    _buildSectionTitle('Minimum Seats'),
                    _buildChipSelector(
                      items: const [2, 4, 5, 6, 7, 8],
                      selected: _selectedMinSeats,
                      onSelected: (value) => setState(() => _selectedMinSeats = value),
                      labelBuilder: (item) => '$item+',
                    ),
                    const SizedBox(height: 24),

                    // AC/Non-AC
                    _buildSectionTitle('Air Conditioning'),
                    _buildChipSelector(
                      items: const [true, false],
                      selected: _selectedHasAC,
                      onSelected: (value) => setState(() => _selectedHasAC = value),
                      labelBuilder: (item) => item ? 'AC' : 'Non-AC',
                    ),
                    const SizedBox(height: 24),

                    // Fuel Type
                    _buildSectionTitle('Fuel Type'),
                    _buildChipSelector(
                      items: const ['petrol', 'diesel', 'electric', 'cng'],
                      selected: _selectedFuelType,
                      onSelected: (value) => setState(() => _selectedFuelType = value),
                      labelBuilder: (item) => _formatType(item),
                    ),
                    const SizedBox(height: 24),

                    // Transmission
                    _buildSectionTitle('Transmission'),
                    _buildChipSelector(
                      items: const ['manual', 'automatic'],
                      selected: _selectedTransmission,
                      onSelected: (value) => setState(() => _selectedTransmission = value),
                      labelBuilder: (item) => _formatType(item),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // Apply Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade800.withValues(alpha: 0.0),
                      Colors.deepPurple.shade800,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildChipSelector<T>({
    required List<T> items,
    required T? selected,
    required Function(T?) onSelected,
    required String Function(T) labelBuilder,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = selected == item;
        return GestureDetector(
          onTap: () => onSelected(isSelected ? null : item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              labelBuilder(item),
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.deepPurple : Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatType(String type) {
    if (type.isEmpty) return type;
    return type[0].toUpperCase() + type.substring(1);
  }

  void _resetFilters() {
    setState(() {
      _selectedVehicleType = null;
      _selectedCity = null;
      _selectedFuelType = null;
      _selectedTransmission = null;
      _selectedHasAC = null;
      _selectedMinSeats = null;
      _priceRange = const RangeValues(5, 50);
    });
  }

  void _applyFilters() {
    final filtersNotifier = ref.read(vehicleFiltersProvider.notifier);

    // Update all filters
    filtersNotifier.updateVehicleType(_selectedVehicleType);
    filtersNotifier.updateCity(_selectedCity);
    filtersNotifier.updatePriceRange(
      _priceRange.start > 5 ? _priceRange.start : null,
      _priceRange.end < 100 ? _priceRange.end : null,
    );
    filtersNotifier.updateMinSeats(_selectedMinSeats);
    filtersNotifier.updateHasAC(_selectedHasAC);
    filtersNotifier.updateFuelType(_selectedFuelType);
    filtersNotifier.updateTransmission(_selectedTransmission);

    Navigator.pop(context);
  }
}
