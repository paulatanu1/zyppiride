import 'package:cloud_firestore/cloud_firestore.dart';

class AvailableVehicle {
  final String id;
  final String userId;
  final String driverName;
  final String? driverPhotoUrl;
  final double driverRating;
  final int totalTrips;
  final VehicleInfo vehicleInfo;
  final LocationInfo location;
  final PricingInfo pricing;
  final List<String> vehicleImages;
  final bool isAvailable;
  final bool isOnline; // Driver online/offline status
  final DateTime? lastOnlineAt; // Last time driver was online
  final DateTime createdAt;

  AvailableVehicle({
    required this.id,
    required this.userId,
    required this.driverName,
    this.driverPhotoUrl,
    required this.driverRating,
    required this.totalTrips,
    required this.vehicleInfo,
    required this.location,
    required this.pricing,
    required this.vehicleImages,
    required this.isAvailable,
    this.isOnline = false,
    this.lastOnlineAt,
    required this.createdAt,
  });

  factory AvailableVehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final vehicleDetails = data['vehicleDetails'] as Map<String, dynamic>? ?? {};
    final locationData = data['location'] as Map<String, dynamic>? ?? {};
    final documents = data['documents'] as Map<String, dynamic>? ?? {};
    final driverData = data['driver'] as Map<String, dynamic>? ?? {};
    final pricingData = data['pricing'] as Map<String, dynamic>? ?? {};

    return AvailableVehicle(
      id: doc.id,
      userId: data['userId'] ?? '',
      driverName: driverData['name'] ?? 'Unknown Driver',
      driverPhotoUrl: driverData['photoUrl'],
      driverRating: (driverData['rating'] ?? 4.5).toDouble(),
      totalTrips: driverData['totalTrips'] ?? 0,
      vehicleInfo: VehicleInfo.fromMap(vehicleDetails),
      location: LocationInfo.fromMap(locationData),
      pricing: PricingInfo.fromMap(pricingData),
      vehicleImages: List<String>.from(documents['vehicleImages'] ?? []),
      isAvailable: data['isAvailable'] ?? true,
      isOnline: data['isOnline'] ?? false,
      lastOnlineAt: (data['lastOnlineAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  AvailableVehicle copyWith({
    String? id,
    String? userId,
    String? driverName,
    String? driverPhotoUrl,
    double? driverRating,
    int? totalTrips,
    VehicleInfo? vehicleInfo,
    LocationInfo? location,
    PricingInfo? pricing,
    List<String>? vehicleImages,
    bool? isAvailable,
    bool? isOnline,
    DateTime? lastOnlineAt,
    DateTime? createdAt,
  }) {
    return AvailableVehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverName: driverName ?? this.driverName,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
      driverRating: driverRating ?? this.driverRating,
      totalTrips: totalTrips ?? this.totalTrips,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      location: location ?? this.location,
      pricing: pricing ?? this.pricing,
      vehicleImages: vehicleImages ?? this.vehicleImages,
      isAvailable: isAvailable ?? this.isAvailable,
      isOnline: isOnline ?? this.isOnline,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VehicleInfo {
  final String type; // car, bike, auto, suv, etc.
  final String brand;
  final String model;
  final String registrationNumber;
  final int year;
  final String fuelType; // petrol, diesel, electric, cng
  final String transmission; // manual, automatic
  final int seatingCapacity;
  final bool hasAC;
  final String color;

  VehicleInfo({
    required this.type,
    required this.brand,
    required this.model,
    required this.registrationNumber,
    required this.year,
    required this.fuelType,
    required this.transmission,
    required this.seatingCapacity,
    required this.hasAC,
    required this.color,
  });

  factory VehicleInfo.fromMap(Map<String, dynamic> map) {
    return VehicleInfo(
      type: map['type']?.toString() ?? 'car',
      brand: map['brand']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      registrationNumber: map['registrationNumber']?.toString() ?? '',
      year: _parseIntSafe(map['year'], DateTime.now().year),
      fuelType: map['fuelType']?.toString() ?? 'petrol',
      transmission: map['transmission']?.toString() ?? 'manual',
      seatingCapacity: _parseIntSafe(map['seatingCapacity'], 4),
      hasAC: map['hasAC'] == true || map['hasAC'] == 'true',
      color: map['color']?.toString() ?? '',
    );
  }

  // Safe int parser that handles both int and String
  static int _parseIntSafe(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  String get displayName => '$brand $model';

  VehicleInfo copyWith({
    String? type,
    String? brand,
    String? model,
    String? registrationNumber,
    int? year,
    String? fuelType,
    String? transmission,
    int? seatingCapacity,
    bool? hasAC,
    String? color,
  }) {
    return VehicleInfo(
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      hasAC: hasAC ?? this.hasAC,
      color: color ?? this.color,
    );
  }
}

class LocationInfo {
  final String city;
  final String state;
  final String area;
  final double? latitude;
  final double? longitude;

  LocationInfo({
    required this.city,
    required this.state,
    required this.area,
    this.latitude,
    this.longitude,
  });

  factory LocationInfo.fromMap(Map<String, dynamic> map) {
    return LocationInfo(
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      area: map['area']?.toString() ?? '',
      latitude: _parseDoubleNullable(map['latitude']),
      longitude: _parseDoubleNullable(map['longitude']),
    );
  }

  // Safe nullable double parser
  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String get displayLocation => area.isNotEmpty ? '$area, $city' : city;

  LocationInfo copyWith({
    String? city,
    String? state,
    String? area,
    double? latitude,
    double? longitude,
  }) {
    return LocationInfo(
      city: city ?? this.city,
      state: state ?? this.state,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class PricingInfo {
  final double basePrice;
  final double perKmRate;
  final double perHourRate;
  final double minimumFare;

  PricingInfo({
    required this.basePrice,
    required this.perKmRate,
    required this.perHourRate,
    required this.minimumFare,
  });

  factory PricingInfo.fromMap(Map<String, dynamic> map) {
    return PricingInfo(
      basePrice: _parseDoubleSafe(map['basePrice'], 50),
      perKmRate: _parseDoubleSafe(map['perKmRate'], 12),
      perHourRate: _parseDoubleSafe(map['perHourRate'], 100),
      minimumFare: _parseDoubleSafe(map['minimumFare'], 100),
    );
  }

  // Safe double parser that handles int, double, and String
  static double _parseDoubleSafe(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  PricingInfo copyWith({
    double? basePrice,
    double? perKmRate,
    double? perHourRate,
    double? minimumFare,
  }) {
    return PricingInfo(
      basePrice: basePrice ?? this.basePrice,
      perKmRate: perKmRate ?? this.perKmRate,
      perHourRate: perHourRate ?? this.perHourRate,
      minimumFare: minimumFare ?? this.minimumFare,
    );
  }
}

// Filter model for search
class VehicleSearchFilters {
  final String? vehicleType;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final int? minSeats;
  final bool? hasAC;
  final String? fuelType;
  final String? transmission;
  final bool onlyAvailable;
  final bool onlyOnline; // Filter for online drivers only

  VehicleSearchFilters({
    this.vehicleType,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.minSeats,
    this.hasAC,
    this.fuelType,
    this.transmission,
    this.onlyAvailable = false, // Default to false to show all vehicles
    this.onlyOnline = true, // Default to true to show only online drivers for riders
  });

  VehicleSearchFilters copyWith({
    String? vehicleType,
    String? city,
    double? minPrice,
    double? maxPrice,
    int? minSeats,
    bool? hasAC,
    String? fuelType,
    String? transmission,
    bool? onlyAvailable,
    bool? onlyOnline,
  }) {
    return VehicleSearchFilters(
      vehicleType: vehicleType ?? this.vehicleType,
      city: city ?? this.city,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minSeats: minSeats ?? this.minSeats,
      hasAC: hasAC ?? this.hasAC,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
      onlyOnline: onlyOnline ?? this.onlyOnline,
    );
  }

  // Clear a specific filter
  // NOTE: cannot use copyWith here — `field ?? this.field` in copyWith means passing null
  // keeps the old value. Each case constructs a new object with that field explicitly null.
  VehicleSearchFilters clearFilter(String filterName) {
    switch (filterName) {
      case 'vehicleType':
        return VehicleSearchFilters(city: city, minPrice: minPrice, maxPrice: maxPrice, minSeats: minSeats, hasAC: hasAC, fuelType: fuelType, transmission: transmission, onlyAvailable: onlyAvailable, onlyOnline: onlyOnline);
      case 'city':
        return VehicleSearchFilters(vehicleType: vehicleType, minPrice: minPrice, maxPrice: maxPrice, minSeats: minSeats, hasAC: hasAC, fuelType: fuelType, transmission: transmission, onlyAvailable: onlyAvailable, onlyOnline: onlyOnline);
      case 'minSeats':
        return VehicleSearchFilters(vehicleType: vehicleType, city: city, minPrice: minPrice, maxPrice: maxPrice, hasAC: hasAC, fuelType: fuelType, transmission: transmission, onlyAvailable: onlyAvailable, onlyOnline: onlyOnline);
      case 'hasAC':
        return VehicleSearchFilters(vehicleType: vehicleType, city: city, minPrice: minPrice, maxPrice: maxPrice, minSeats: minSeats, fuelType: fuelType, transmission: transmission, onlyAvailable: onlyAvailable, onlyOnline: onlyOnline);
      case 'fuelType':
        return VehicleSearchFilters(vehicleType: vehicleType, city: city, minPrice: minPrice, maxPrice: maxPrice, minSeats: minSeats, hasAC: hasAC, transmission: transmission, onlyAvailable: onlyAvailable, onlyOnline: onlyOnline);
      case 'transmission':
        return VehicleSearchFilters(vehicleType: vehicleType, city: city, minPrice: minPrice, maxPrice: maxPrice, minSeats: minSeats, hasAC: hasAC, fuelType: fuelType, onlyAvailable: onlyAvailable, onlyOnline: onlyOnline);
      default:
        return this;
    }
  }

  // Check if any filter is active
  bool get hasActiveFilters =>
      vehicleType != null ||
      city != null ||
      minPrice != null ||
      maxPrice != null ||
      minSeats != null ||
      hasAC != null ||
      fuelType != null ||
      transmission != null;

  // Get count of active filters
  int get activeFilterCount {
    int count = 0;
    if (vehicleType != null) count++;
    if (city != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minSeats != null) count++;
    if (hasAC != null) count++;
    if (fuelType != null) count++;
    if (transmission != null) count++;
    return count;
  }

  // Reset all filters
  static VehicleSearchFilters empty() => VehicleSearchFilters();
}
