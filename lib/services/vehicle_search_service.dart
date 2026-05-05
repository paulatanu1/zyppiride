import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';
import '../models/available_vehicle_model.dart';

class VehicleSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<Result<List<AvailableVehicle>>> searchVehicles({
    required VehicleSearchFilters filters,
    int limit = 20,
  }) async {
    AppLogger.firestore('QUERY', TestMode.vehiclesCollection);
    AppLogger.info('Searching vehicles: ${_filtersToString(filters)}');

    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(TestMode.vehiclesCollection);

      // --- Firestore-level filters (all have composite indexes) ---

      // isOnline is the default filter (true by default in VehicleSearchFilters).
      // Index: isOnline + location.city   (existing)
      // Index: isOnline + location.city + vehicleDetails.type  (added)
      // Index: isOnline + vehicleDetails.type  (added)
      if (filters.onlyOnline) {
        query = query.where('isOnline', isEqualTo: true);
      }

      // isAvailable uses the existing index:
      // location.city + vehicleDetails.type + isAvailable
      if (filters.onlyAvailable) {
        query = query.where('isAvailable', isEqualTo: true);
      }

      if (filters.city != null && filters.city!.isNotEmpty) {
        query = query.where('location.city', isEqualTo: filters.city);
      }

      if (filters.vehicleType != null && filters.vehicleType!.isNotEmpty) {
        query = query.where('vehicleDetails.type', isEqualTo: filters.vehicleType);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      AppLogger.debug('Query returned ${snapshot.docs.length} documents');

      return _processVehicleDocs(snapshot.docs, filters);
    } catch (e, stackTrace) {
      // Do NOT fall back to a broader query — a missing index or permission
      // error should surface as a real failure so it can be diagnosed.
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'searchVehicles');
      return Result.failure(exception);
    }
  }

  // ---------------------------------------------------------------------------
  // Process results
  // ---------------------------------------------------------------------------

  Future<Result<List<AvailableVehicle>>> _processVehicleDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    VehicleSearchFilters filters,
  ) async {
    // Parallel user reads — one Future.wait instead of N sequential awaits.
    final settled = await Future.wait(
      docs.map((doc) => _createVehicleFromDoc(doc)),
      eagerError: false,
    );

    var vehicles = settled.whereType<AvailableVehicle>().toList();

    // --- Client-side filters for fields that can't easily be indexed ---
    // (hasAC, fuelType, transmission, seats, price are low-cardinality or
    //  range filters added on top of the already-filtered Firestore result set.)

    if (filters.hasAC != null) {
      vehicles = vehicles
          .where((v) => v.vehicleInfo.hasAC == filters.hasAC)
          .toList();
    }
    if (filters.fuelType != null && filters.fuelType!.isNotEmpty) {
      vehicles = vehicles
          .where((v) =>
              v.vehicleInfo.fuelType.toLowerCase() ==
              filters.fuelType!.toLowerCase())
          .toList();
    }
    if (filters.transmission != null && filters.transmission!.isNotEmpty) {
      vehicles = vehicles
          .where((v) =>
              v.vehicleInfo.transmission.toLowerCase() ==
              filters.transmission!.toLowerCase())
          .toList();
    }
    if (filters.minSeats != null) {
      vehicles = vehicles
          .where((v) => v.vehicleInfo.seatingCapacity >= filters.minSeats!)
          .toList();
    }
    if (filters.minPrice != null) {
      vehicles = vehicles
          .where((v) => v.pricing.perKmRate >= filters.minPrice!)
          .toList();
    }
    if (filters.maxPrice != null) {
      vehicles = vehicles
          .where((v) => v.pricing.perKmRate <= filters.maxPrice!)
          .toList();
    }

    AppLogger.success('Found ${vehicles.length} vehicles after filtering');
    return Result.success(vehicles);
  }

  // ---------------------------------------------------------------------------
  // Build a single AvailableVehicle from a Firestore document.
  // The user read runs concurrently with sibling calls via Future.wait above.
  // ---------------------------------------------------------------------------

  Future<AvailableVehicle?> _createVehicleFromDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final userId = data['userId'] as String? ?? '';
    final vehicleDetails = data['vehicleDetails'] as Map<String, dynamic>? ?? {};
    final locationData = data['location'] as Map<String, dynamic>? ?? {};
    final documents = data['documents'] as Map<String, dynamic>? ?? {};
    final pricingData = data['pricing'] as Map<String, dynamic>? ?? {};

    String driverName = 'Vehicle Owner';
    String? driverPhotoUrl;
    double driverRating = 4.5;
    int totalTrips = 0;

    if (userId.isNotEmpty) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(userId).get();
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
        AppLogger.warning('Could not fetch user data for $userId: $e');
      }
    }

    List<String> vehicleImages = [];
    if (documents['vehicleImages'] != null) {
      vehicleImages = List<String>.from(documents['vehicleImages'] ?? []);
    }

    final bool isAvailable = data['isAvailable'] as bool? ??
        (data['documentStatus'] == 'approved' ||
            data['documentStatus'] == 'verified' ||
            data['documentStatus'] == 'active');

    final bool isOnline = data['isOnline'] as bool? ?? false;
    final DateTime? lastOnlineAt =
        (data['lastOnlineAt'] as Timestamp?)?.toDate();

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
      isOnline: isOnline,
      lastOnlineAt: lastOnlineAt,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Dropdown data — reads a single metadata document instead of all vehicles
  // ---------------------------------------------------------------------------

  /// Returns the list of cities from the search-metadata document.
  /// Falls back to a limited collection scan only if the doc doesn't exist yet
  /// (i.e., before the first vehicle is registered with the updated app).
  Future<Result<List<String>>> getAvailableCities() async {
    AppLogger.firestore('GET', 'metadata', docId: 'vehicleSearchMeta');

    try {
      final metaDoc =
          await _firestore.doc('metadata/vehicleSearchMeta').get();

      if (metaDoc.exists) {
        final cities =
            List<String>.from(metaDoc.data()?['cities'] ?? <String>[]);
        cities.sort();
        AppLogger.success('Cities from metadata: $cities');
        return Result.success(cities);
      }

      // Metadata document not yet seeded — limited fallback (max 100 docs).
      AppLogger.warning(
          'metadata/vehicleSearchMeta not found, running limited fallback');
      final snapshot = await _firestore
          .collection(TestMode.vehiclesCollection)
          .limit(100)
          .get();

      final cities = snapshot.docs
          .map((doc) {
            final location =
                doc.data()['location'] as Map<String, dynamic>?;
            return location?['city'] as String? ?? '';
          })
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return Result.success(cities);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getAvailableCities');
      return Result.failure(exception);
    }
  }

  /// Returns the list of vehicle types from the search-metadata document.
  Future<Result<List<String>>> getVehicleTypes() async {
    AppLogger.firestore('GET', 'metadata', docId: 'vehicleSearchMeta');

    try {
      final metaDoc =
          await _firestore.doc('metadata/vehicleSearchMeta').get();

      if (metaDoc.exists) {
        final types =
            List<String>.from(metaDoc.data()?['vehicleTypes'] ?? <String>[]);
        types.sort();
        AppLogger.success('Vehicle types from metadata: $types');
        return Result.success(types);
      }

      AppLogger.warning(
          'metadata/vehicleSearchMeta not found, running limited fallback');
      final snapshot = await _firestore
          .collection(TestMode.vehiclesCollection)
          .limit(100)
          .get();

      final types = snapshot.docs
          .map((doc) {
            final details =
                doc.data()['vehicleDetails'] as Map<String, dynamic>?;
            return details?['type'] as String? ?? '';
          })
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return Result.success(types);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getVehicleTypes');
      return Result.failure(exception);
    }
  }

  // ---------------------------------------------------------------------------
  // Single vehicle fetch
  // ---------------------------------------------------------------------------

  Future<Result<AvailableVehicle>> getVehicleById(String vehicleId) async {
    AppLogger.firestore('GET', TestMode.vehiclesCollection, docId: vehicleId);

    try {
      final doc = await _firestore
          .collection(TestMode.vehiclesCollection)
          .doc(vehicleId)
          .get();

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _filtersToString(VehicleSearchFilters filters) {
    final parts = <String>[];
    if (filters.vehicleType != null) parts.add('type=${filters.vehicleType}');
    if (filters.city != null) parts.add('city=${filters.city}');
    if (filters.minPrice != null) parts.add('minPrice=${filters.minPrice}');
    if (filters.maxPrice != null) parts.add('maxPrice=${filters.maxPrice}');
    if (filters.minSeats != null) parts.add('minSeats=${filters.minSeats}');
    if (filters.hasAC != null) parts.add('hasAC=${filters.hasAC}');
    if (filters.fuelType != null) parts.add('fuelType=${filters.fuelType}');
    if (filters.transmission != null) {
      parts.add('transmission=${filters.transmission}');
    }
    if (filters.onlyAvailable) parts.add('onlyAvailable=true');
    if (filters.onlyOnline) parts.add('onlyOnline=true');
    return parts.isEmpty ? 'none' : parts.join(', ');
  }

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
