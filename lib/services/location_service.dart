import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? area;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.state,
    this.postalCode,
    this.area,
  });

  String get shortAddress {
    if (area != null && city != null) {
      return '$area, $city';
    }
    if (city != null) {
      return city!;
    }
    return address;
  }

  String get cityState {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    return parts.join(', ');
  }

  LocationData copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    String? area,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      area: area ?? this.area,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'area': area,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      area: json['area'] as String?,
    );
  }
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationService {
  // Check if location services are enabled and permissions granted
  Future<Result<LocationPermissionStatus>> checkPermission() async {
    AppLogger.info('Checking location permission...');

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        return Result.success(LocationPermissionStatus.serviceDisabled);
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        AppLogger.info('Location permission is denied, requesting...');
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        AppLogger.warning('Location permission denied');
        return Result.success(LocationPermissionStatus.denied);
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('Location permission denied forever');
        return Result.success(LocationPermissionStatus.deniedForever);
      }

      AppLogger.success('Location permission granted');
      return Result.success(LocationPermissionStatus.granted);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'checkPermission');
      return Result.failure(exception);
    }
  }

  // Get current location
  Future<Result<LocationData>> getCurrentLocation() async {
    AppLogger.info('Getting current location...');

    try {
      // Check permission first
      final permissionResult = await checkPermission();
      LocationPermissionStatus? permissionStatus;

      permissionResult.when(
        success: (status) => permissionStatus = status,
        failure: (e) => throw e,
      );

      if (permissionStatus != LocationPermissionStatus.granted) {
        final errorMessage = switch (permissionStatus) {
          LocationPermissionStatus.serviceDisabled => 'Location services are disabled',
          LocationPermissionStatus.denied => 'Location permission denied',
          LocationPermissionStatus.deniedForever => 'Location permission permanently denied',
          _ => 'Location permission not granted',
        };
        return Result.failure(ValidationException(message: errorMessage));
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      AppLogger.debug('Got coordinates: ${position.latitude}, ${position.longitude}');

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        return Result.failure(DatabaseException.notFound('Address'));
      }

      Placemark place = placemarks.first;
      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: _formatAddress(place),
        city: place.locality ?? place.subLocality,
        state: place.administrativeArea,
        postalCode: place.postalCode,
        area: place.subLocality ?? place.locality,
      );

      AppLogger.success('Location detected: ${locationData.shortAddress}');
      return Result.success(locationData);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getCurrentLocation');
      return Result.failure(exception);
    }
  }

  // Get location from address string (using geocoding)
  Future<Result<LocationData>> getLocationFromAddress(String address) async {
    AppLogger.info('Getting location from address: $address');

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return Result.failure(DatabaseException.notFound('Location'));
      }

      Location location = locations.first;

      // Get detailed address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        return Result.success(LocationData(
          latitude: location.latitude,
          longitude: location.longitude,
          address: address,
        ));
      }

      Placemark place = placemarks.first;
      final locationData = LocationData(
        latitude: location.latitude,
        longitude: location.longitude,
        address: address,
        city: place.locality ?? place.subLocality,
        state: place.administrativeArea,
        postalCode: place.postalCode,
        area: place.subLocality ?? place.locality,
      );

      AppLogger.success('Location found: ${locationData.cityState}');
      return Result.success(locationData);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getLocationFromAddress');
      return Result.failure(exception);
    }
  }

  // Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  // Open app settings (for permission)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  String _formatAddress(Placemark place) {
    List<String> parts = [];
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);
    if (place.postalCode?.isNotEmpty == true) parts.add(place.postalCode!);
    return parts.join(', ');
  }
}
