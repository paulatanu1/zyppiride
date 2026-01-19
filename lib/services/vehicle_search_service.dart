import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';
import '../models/available_vehicle_model.dart';

class VehicleSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch available vehicles with filters - queries Firebase directly
  Future<Result<List<AvailableVehicle>>> searchVehicles({
    required VehicleSearchFilters filters,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    AppLogger.firestore('QUERY', 'vehicles');
    AppLogger.info('Searching vehicles with filters: ${_filtersToString(filters)}');

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('vehicles');

      // Filter by document status (only approved/verified vehicles)
      // If no isAvailable field, we check documentStatus
      if (filters.onlyAvailable) {
        // Try to get vehicles that are available or have approved status
        query = query.where('documentStatus', whereIn: ['approved', 'verified', 'active']);
      }

      // Filter by city - this is the main location-based filter
      if (filters.city != null && filters.city!.isNotEmpty) {
        query = query.where('location.city', isEqualTo: filters.city);
      }

      // Filter by vehicle type
      if (filters.vehicleType != null && filters.vehicleType!.isNotEmpty) {
        query = query.where('vehicleDetails.type', isEqualTo: filters.vehicleType);
      }

      // Note: Additional filters applied client-side due to Firestore compound query limitations

      // Limit results
      query = query.limit(limit);

      final querySnapshot = await query.get();

      AppLogger.debug('Raw query returned ${querySnapshot.docs.length} documents');

      // If no results with strict filters, try without documentStatus filter
      if (querySnapshot.docs.isEmpty && filters.onlyAvailable) {
        AppLogger.debug('No results with status filter, trying without...');
        Query<Map<String, dynamic>> fallbackQuery = _firestore.collection('vehicles');

        if (filters.city != null && filters.city!.isNotEmpty) {
          fallbackQuery = fallbackQuery.where('location.city', isEqualTo: filters.city);
        }

        if (filters.vehicleType != null && filters.vehicleType!.isNotEmpty) {
          fallbackQuery = fallbackQuery.where('vehicleDetails.type', isEqualTo: filters.vehicleType);
        }

        fallbackQuery = fallbackQuery.limit(limit);

        final fallbackSnapshot = await fallbackQuery.get();
        AppLogger.debug('Fallback query returned ${fallbackSnapshot.docs.length} documents');

        if (fallbackSnapshot.docs.isNotEmpty) {
          return _processVehicleDocs(fallbackSnapshot.docs, filters);
        }
      }

      return _processVehicleDocs(querySnapshot.docs, filters);
    } catch (e, _) {
      AppLogger.error('Search error: $e');

      // If compound query fails, try simpler query
      try {
        AppLogger.debug('Trying simple query without compound filters...');
        final simpleQuery = await _firestore
            .collection('vehicles')
            .limit(limit)
            .get();

        AppLogger.debug('Simple query returned ${simpleQuery.docs.length} documents');
        return _processVehicleDocs(simpleQuery.docs, filters);
      } catch (e2, stackTrace2) {
        final exception = ErrorHandler.handle(e2, stackTrace2);
        AppLogger.logException(exception, context: 'searchVehicles');
        return Result.failure(exception);
      }
    }
  }

  Future<Result<List<AvailableVehicle>>> _processVehicleDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    VehicleSearchFilters filters,
  ) async {
    List<AvailableVehicle> vehicles = [];

    for (var doc in docs) {
      try {
        final vehicle = await _createVehicleFromDoc(doc);
        if (vehicle != null) {
          vehicles.add(vehicle);
        }
      } catch (e) {
        AppLogger.warning('Error processing vehicle ${doc.id}: $e');
      }
    }

    // Apply client-side filters for fields that couldn't be queried
    if (filters.city != null && filters.city!.isNotEmpty) {
      vehicles = vehicles.where((v) =>
        v.location.city.toLowerCase() == filters.city!.toLowerCase()
      ).toList();
    }

    if (filters.vehicleType != null && filters.vehicleType!.isNotEmpty) {
      vehicles = vehicles.where((v) =>
        v.vehicleInfo.type.toLowerCase() == filters.vehicleType!.toLowerCase()
      ).toList();
    }

    if (filters.hasAC != null) {
      vehicles = vehicles.where((v) => v.vehicleInfo.hasAC == filters.hasAC).toList();
    }

    if (filters.fuelType != null && filters.fuelType!.isNotEmpty) {
      vehicles = vehicles.where((v) =>
        v.vehicleInfo.fuelType.toLowerCase() == filters.fuelType!.toLowerCase()
      ).toList();
    }

    if (filters.transmission != null && filters.transmission!.isNotEmpty) {
      vehicles = vehicles.where((v) =>
        v.vehicleInfo.transmission.toLowerCase() == filters.transmission!.toLowerCase()
      ).toList();
    }

    if (filters.minSeats != null) {
      vehicles = vehicles.where((v) => v.vehicleInfo.seatingCapacity >= filters.minSeats!).toList();
    }

    if (filters.minPrice != null) {
      vehicles = vehicles.where((v) => v.pricing.perKmRate >= filters.minPrice!).toList();
    }

    if (filters.maxPrice != null) {
      vehicles = vehicles.where((v) => v.pricing.perKmRate <= filters.maxPrice!).toList();
    }

    AppLogger.success('Found ${vehicles.length} vehicles after filtering');
    return Result.success(vehicles);
  }

  Future<AvailableVehicle?> _createVehicleFromDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final userId = data['userId'] as String? ?? '';
    final vehicleDetails = data['vehicleDetails'] as Map<String, dynamic>? ?? {};
    final locationData = data['location'] as Map<String, dynamic>? ?? {};
    final documents = data['documents'] as Map<String, dynamic>? ?? {};
    final pricingData = data['pricing'] as Map<String, dynamic>? ?? {};

    // Try to get driver info from users collection
    String driverName = 'Vehicle Owner';
    String? driverPhotoUrl;
    double driverRating = 4.5;
    int totalTrips = 0;

    if (userId.isNotEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          driverName = userData?['name']?.toString() ??
                       userData?['displayName']?.toString() ??
                       'Vehicle Owner';
          driverPhotoUrl = userData?['photoUrl']?.toString() ??
                          userData?['profileImageUrl']?.toString();
          driverRating = _parseDoubleSafe(userData?['rating'], 4.5);
          totalTrips = _parseIntSafe(userData?['totalTrips'], 0);
        }
      } catch (e) {
        // Permission denied or other error - continue with defaults
        AppLogger.warning('Could not fetch user data for $userId: $e');
      }
    }

    // Get vehicle images
    List<String> vehicleImages = [];
    if (documents['vehicleImages'] != null) {
      vehicleImages = List<String>.from(documents['vehicleImages'] ?? []);
    }

    // Check availability - look for isAvailable field or documentStatus
    bool isAvailable = data['isAvailable'] ??
        (data['documentStatus'] == 'approved' ||
         data['documentStatus'] == 'verified' ||
         data['documentStatus'] == 'active' ||
         data['documentStatus'] == 'pending'); // Show pending too for now

    return AvailableVehicle(
      id: doc.id,
      userId: userId,
      driverName: driverName,
      driverPhotoUrl: driverPhotoUrl,
      driverRating: driverRating,
      totalTrips: totalTrips,
      vehicleInfo: VehicleInfo.fromMap(vehicleDetails),
      location: LocationInfo.fromMap(locationData),
      pricing: PricingInfo.fromMap(pricingData),
      vehicleImages: vehicleImages,
      isAvailable: isAvailable,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Get all vehicles (no filter) - useful for debugging
  Future<Result<List<AvailableVehicle>>> getAllVehicles({int limit = 20}) async {
    AppLogger.firestore('QUERY', 'vehicles', docId: 'all');

    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .limit(limit)
          .get();

      AppLogger.debug('Found ${querySnapshot.docs.length} total vehicles');

      return _processVehicleDocs(querySnapshot.docs, VehicleSearchFilters());
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getAllVehicles');
      return Result.failure(exception);
    }
  }

  // Get distinct cities for filter dropdown
  Future<Result<List<String>>> getAvailableCities() async {
    AppLogger.firestore('QUERY', 'vehicles', docId: 'distinct cities');

    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .get();

      final cities = querySnapshot.docs
          .map((doc) {
            final location = doc.data()['location'] as Map<String, dynamic>?;
            return location?['city'] as String? ?? '';
          })
          .where((city) => city.isNotEmpty)
          .toSet()
          .toList();

      cities.sort();
      AppLogger.success('Found ${cities.length} cities: $cities');
      return Result.success(cities);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getAvailableCities');
      return Result.failure(exception);
    }
  }

  // Get distinct vehicle types for filter dropdown
  Future<Result<List<String>>> getVehicleTypes() async {
    AppLogger.firestore('QUERY', 'vehicles', docId: 'distinct types');

    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .get();

      final types = querySnapshot.docs
          .map((doc) {
            final details = doc.data()['vehicleDetails'] as Map<String, dynamic>?;
            return details?['type'] as String? ?? '';
          })
          .where((type) => type.isNotEmpty)
          .toSet()
          .toList();

      types.sort();
      AppLogger.success('Found ${types.length} vehicle types: $types');
      return Result.success(types);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getVehicleTypes');
      return Result.failure(exception);
    }
  }

  // Get vehicle by ID
  Future<Result<AvailableVehicle>> getVehicleById(String vehicleId) async {
    AppLogger.firestore('GET', 'vehicles', docId: vehicleId);

    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();

      if (!doc.exists) {
        return Result.failure(DatabaseException.notFound('Vehicle'));
      }

      final vehicle = await _createVehicleFromDoc(doc);
      if (vehicle == null) {
        return Result.failure(DatabaseException.notFound('Vehicle data'));
      }

      AppLogger.success('Vehicle loaded: ${vehicle.vehicleInfo.displayName}');
      return Result.success(vehicle);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getVehicleById');
      return Result.failure(exception);
    }
  }

  // Get vehicles by city
  Future<Result<List<AvailableVehicle>>> getVehiclesByCity({
    required String city,
    int limit = 20,
  }) async {
    AppLogger.firestore('QUERY', 'vehicles', docId: 'city: $city');

    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .where('location.city', isEqualTo: city)
          .limit(limit)
          .get();

      return _processVehicleDocs(querySnapshot.docs, VehicleSearchFilters());
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getVehiclesByCity');
      return Result.failure(exception);
    }
  }

  String _filtersToString(VehicleSearchFilters filters) {
    final parts = <String>[];
    if (filters.vehicleType != null) parts.add('type=${filters.vehicleType}');
    if (filters.city != null) parts.add('city=${filters.city}');
    if (filters.minPrice != null) parts.add('minPrice=${filters.minPrice}');
    if (filters.maxPrice != null) parts.add('maxPrice=${filters.maxPrice}');
    if (filters.minSeats != null) parts.add('minSeats=${filters.minSeats}');
    if (filters.hasAC != null) parts.add('hasAC=${filters.hasAC}');
    if (filters.fuelType != null) parts.add('fuelType=${filters.fuelType}');
    if (filters.transmission != null) parts.add('transmission=${filters.transmission}');
    if (filters.onlyAvailable) parts.add('onlyAvailable=true');
    return parts.isEmpty ? 'none' : parts.join(', ');
  }

  // Safe type parsing helpers
  static double _parseDoubleSafe(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static int _parseIntSafe(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}
