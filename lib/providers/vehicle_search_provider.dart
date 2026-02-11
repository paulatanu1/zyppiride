import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/available_vehicle_model.dart';
import '../services/vehicle_search_service.dart';
import '../core/utils/app_logger.dart';

// Service provider
final vehicleSearchServiceProvider = Provider<VehicleSearchService>((ref) {
  return VehicleSearchService();
});

// Search filters state
final vehicleFiltersProvider = StateNotifierProvider<VehicleFiltersNotifier, VehicleSearchFilters>((ref) {
  return VehicleFiltersNotifier();
});

class VehicleFiltersNotifier extends StateNotifier<VehicleSearchFilters> {
  VehicleFiltersNotifier() : super(VehicleSearchFilters());

  void updateVehicleType(String? type) {
    state = state.copyWith(vehicleType: type);
  }

  void updateCity(String? city) {
    state = state.copyWith(city: city);
  }

  void updatePriceRange(double? min, double? max) {
    state = VehicleSearchFilters(
      vehicleType: state.vehicleType,
      city: state.city,
      minPrice: min,
      maxPrice: max,
      minSeats: state.minSeats,
      hasAC: state.hasAC,
      fuelType: state.fuelType,
      transmission: state.transmission,
      onlyAvailable: state.onlyAvailable,
    );
  }

  void updateMinSeats(int? seats) {
    state = state.copyWith(minSeats: seats);
  }

  void updateHasAC(bool? hasAC) {
    state = VehicleSearchFilters(
      vehicleType: state.vehicleType,
      city: state.city,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
      minSeats: state.minSeats,
      hasAC: hasAC,
      fuelType: state.fuelType,
      transmission: state.transmission,
      onlyAvailable: state.onlyAvailable,
    );
  }

  void updateFuelType(String? fuelType) {
    state = state.copyWith(fuelType: fuelType);
  }

  void updateTransmission(String? transmission) {
    state = state.copyWith(transmission: transmission);
  }

  void updateOnlyOnline(bool onlyOnline) {
    state = state.copyWith(onlyOnline: onlyOnline);
  }

  void clearAllFilters() {
    state = VehicleSearchFilters();
  }

  void clearFilter(String filterName) {
    state = state.clearFilter(filterName);
  }
}

// Vehicle search results state
class VehicleSearchState {
  final List<AvailableVehicle> vehicles;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  VehicleSearchState({
    this.vehicles = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  VehicleSearchState copyWith({
    List<AvailableVehicle>? vehicles,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return VehicleSearchState(
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

// Vehicle search results provider
final vehicleSearchProvider = StateNotifierProvider<VehicleSearchNotifier, VehicleSearchState>((ref) {
  final service = ref.watch(vehicleSearchServiceProvider);
  final filters = ref.watch(vehicleFiltersProvider);
  return VehicleSearchNotifier(service, filters);
});

class VehicleSearchNotifier extends StateNotifier<VehicleSearchState> {
  final VehicleSearchService _service;
  final VehicleSearchFilters _filters;

  VehicleSearchNotifier(this._service, this._filters) : super(VehicleSearchState()) {
    // Auto-search when filters change
    searchVehicles();
  }

  Future<void> searchVehicles({bool refresh = true}) async {
    if (state.isLoading) return;

    AppLogger.info('Searching vehicles with ${_filters.activeFilterCount} active filters');

    state = state.copyWith(
      isLoading: true,
      error: null,
      vehicles: refresh ? [] : state.vehicles,
    );

    final result = await _service.searchVehicles(filters: _filters);

    result.when(
      success: (vehicles) {
        state = state.copyWith(
          vehicles: refresh ? vehicles : [...state.vehicles, ...vehicles],
          isLoading: false,
          hasMore: vehicles.length >= 10,
        );
      },
      failure: (exception) {
        state = state.copyWith(
          isLoading: false,
          error: exception.message,
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.vehicles.isEmpty) return;

    AppLogger.info('Loading more vehicles...');
    await searchVehicles(refresh: false);
  }

  void refresh() {
    searchVehicles(refresh: true);
  }
}

// Available cities provider
final availableCitiesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(vehicleSearchServiceProvider);
  final result = await service.getAvailableCities();
  return result.when(
    success: (cities) => cities,
    failure: (_) => <String>[],
  );
});

// Available vehicle types provider
final availableVehicleTypesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(vehicleSearchServiceProvider);
  final result = await service.getVehicleTypes();
  return result.when(
    success: (types) => types,
    failure: (_) => <String>[],
  );
});

// Selected vehicle provider (for booking flow)
final selectedVehicleProvider = StateProvider<AvailableVehicle?>((ref) => null);
