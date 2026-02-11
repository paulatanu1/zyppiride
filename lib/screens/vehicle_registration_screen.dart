import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/utils/app_logger.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:intl/intl.dart';
import '../services/vehicle_service.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  final String userId;

  const VehicleRegistrationScreen({super.key, required this.userId});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _analytics = FirebaseAnalytics.instance;
  final _manualAddressController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _vehicleService = VehicleService();

  // NEW CONTROLLERS for new fields
  final TextEditingController _licenseNumberController = TextEditingController();
  DateTime? _pucValidUptoDate;
  DateTime? _insuranceValidUptoDate;
  DateTime? _licenseValidUptoDate;
  bool _isACVariant = false;

  // Image lists - MODIFIED: Only vehicle photos on this screen
  final Map<String, List<File>> _imageGroups = {
    'vehicle': [],
  };

  // Upload progress tracking
  final Map<String, double> _uploadProgress = {};
  bool _showUploadProgress = false;

  // Location tracking
  double? latitude;
  double? longitude;
  String? locationAddress;
  String? city;
  String? state;
  String? postalCode;
  bool isLoadingLocation = false;
  bool locationPermissionDenied = false;
  bool useManualAddress = false;

  // Form fields
  String? selectedVehicleCategory;
  String? selectedBrand;
  String? selectedModel;
  String? selectedColor;
  final yearController = TextEditingController();
  final registrationController = TextEditingController();
  final seatingController = TextEditingController();
  final _passengerCapacityController = TextEditingController();

  List<String> colors = [];
  List<String> brands = [];
  List<String> models = [];

  bool isLoading = true;
  bool isSubmitting = false;
  bool isOffline = false;

  Map<String, dynamic>? catalogData;

  // Google Places API Key
  static const String googleApiKey = "AIzaSyABUF7GCEM6h1n3isugLj2qOEySpTtxd1I";

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadCatalogData();
    _logScreenView();
    Future.delayed(const Duration(milliseconds: 500), () {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    yearController.dispose();
    registrationController.dispose();
    seatingController.dispose();
    _passengerCapacityController.dispose();
    _passengerCapacityController.dispose();
    _scrollController.dispose();
    _manualAddressController.dispose();
    _searchFocusNode.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  // REGISTRATION NUMBER AUTO-FORMATTER
  String _formatRegistrationNumber(String value) {
    String cleaned = value.replaceAll('-', '').toUpperCase();
    if (cleaned.isEmpty) return '';

    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < cleaned.length && i < 10; i++) {
      if (i == 2 || i == 4 || i == 6) {
        formatted.write('-');
      }
      formatted.write(cleaned[i]);
    }
    return formatted.toString();
  }

  String? _validateRegistrationNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Registration number is required';
    }
    String cleaned = value.replaceAll('-', '');
    if (cleaned.length < 8 || cleaned.length > 10) {
      return 'Invalid registration number format';
    }
    if (!RegExp(r'^[A-Z]{2}').hasMatch(cleaned)) {
      return 'State code must be 2 letters';
    }
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}').hasMatch(cleaned)) {
      return 'RTO code must be 2 digits';
    }
    return null;
  }

  // Date Picker
  Future<void> _selectDate(BuildContext context, String fieldType) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      setState(() {
        switch (fieldType) {
          case 'puc':
            _pucValidUptoDate = picked;
            break;
          case 'insurance':
            _insuranceValidUptoDate = picked;
            break;
          case 'license':
            _licenseValidUptoDate = picked;
            break;
        }
      });
    }
  }

  // ANALYTICS
  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'VehicleRegistration',
      screenClass: 'VehicleRegistrationScreen',
    );
  }

  Future<void> _logEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: parameters?.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  // CONNECTIVITY
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOffline = connectivityResult.contains(ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      setState(() {
        isOffline = result.contains(ConnectivityResult.none);
      });
      if (!isOffline && mounted) {
        _showSnackBar('Back online! You can now submit your registration.');
      }
    });
  }

  // LOCATION SERVICES
  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationPermissionDenied = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          isLoadingLocation = false;
          locationPermissionDenied = true;
        });
        _showSnackBar('Location services are disabled. Please enable them in settings.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            isLoadingLocation = false;
            locationPermissionDenied = true;
          });
          _showSnackBar('Location permission denied. Please enter address manually.', isError: true);
          await _logEvent('location_permission_denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          isLoadingLocation = false;
          locationPermissionDenied = true;
        });
        _showSnackBar('Location permissions are permanently denied. Please enable in settings.', isError: true);
        await _logEvent('location_permission_denied_forever');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          latitude = position.latitude;
          longitude = position.longitude;
          city = place.locality ?? place.subLocality;
          state = place.administrativeArea;
          postalCode = place.postalCode;
          locationAddress = _formatAddress(place);
          isLoadingLocation = false;
          useManualAddress = false;
        });
        _showSnackBar('Location detected successfully!', isSuccess: true);
          await _logEvent('location_detected', parameters: {
          'city': city,
          'state': state,
        });
      }
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      _showSnackBar('Failed to get location: $e', isError: true);
      await _logEvent('location_error', parameters: {'error': e.toString()});
    }
  }

  String _formatAddress(Placemark place) {
    List<String> parts = [];
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);
    if (place.postalCode?.isNotEmpty == true) parts.add(place.postalCode!);
    return parts.join(', ');
  }

  void onPlaceSelected(Prediction prediction) async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      List<Location> locations = await locationFromAddress(prediction.description ?? '');
      if (locations.isNotEmpty && mounted) {
        Location location = locations[0];
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          Placemark place = placemarks[0];
          setState(() {
            latitude = location.latitude;
            longitude = location.longitude;
            city = place.locality ?? place.subLocality;
            state = place.administrativeArea;
            postalCode = place.postalCode;
            locationAddress = prediction.description ?? _formatAddress(place);
            isLoadingLocation = false;
            useManualAddress = false;
            _manualAddressController.clear();
          });
          _showSnackBar('Location selected successfully!', isSuccess: true);
              await _logEvent('manual_location_selected', parameters: {
            'city': city,
            'state': state,
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      _showSnackBar('Failed to get coordinates for selected place: $e', isError: true);
    }
  }


  // CATALOG DATA
  Future<void> _loadCatalogData() async {
  final startTime = DateTime.now();
  try {
    final result = await _vehicleService.fetchVehicleCatalog(useCache: isOffline);

    result.when(
      success: (data) {
        if (mounted) {
          setState(() {
            catalogData = data;
            colors = List<String>.from(catalogData?['colors'] ?? []);
            isLoading = false;
          });
        }
      },
      failure: (exception) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          _showSnackBar(exception.message, isError: true);
        }
      },
    );

    if (result.isSuccess) {
      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      await _logEvent('catalog_loaded', parameters: {
        'load_time_ms': loadTime,
      });
    }
  } catch (e) {
    setState(() {
      isLoading = false;
    });
    _showSnackBar('Failed to load catalog: $e', isError: true);
    await _logEvent('catalog_load_error', parameters: {'error': e.toString()});
  }
}


  void updateBrandsAndModels() {
    if (selectedVehicleCategory == null || catalogData == null) {
      setState(() {
        brands = [];
        models = [];
        selectedBrand = null;
        selectedModel = null;
      });
      return;
    }

    final categoryData = catalogData?[selectedVehicleCategory] as Map<String, dynamic>?;

    if (categoryData != null) {
      setState(() {
        brands = categoryData.keys.map((e) => e.toString()).toList();
        selectedBrand = null;
        selectedModel = null;
        models = [];
      });
      _logEvent('category_selected', parameters: {
        'category': selectedVehicleCategory,
      });
    }
  }

  void updateModels() {
    if (selectedVehicleCategory == null || selectedBrand == null || catalogData == null) {
      setState(() {
        models = [];
        selectedModel = null;
      });
      return;
    }

    final categoryData = catalogData?[selectedVehicleCategory] as Map<String, dynamic>?;
    final brandData = categoryData?[selectedBrand];

    if (brandData is Map) {
      setState(() {
        models = brandData.keys.map((e) => e.toString()).toList();
        selectedModel = null;
      });
    } else if (brandData is List) {
      setState(() {
        models = List<String>.from(brandData);
        selectedModel = null;
      });
    }

    _logEvent('brand_selected', parameters: {
      'category': selectedVehicleCategory,
      'brand': selectedBrand,
    });
  }

  // IMAGE HANDLING
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      int quality = 85;
      File? compressedFile;

      while (quality >= 10) {
        final result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          minWidth: 1920,
          minHeight: 1080,
        );

        if (result == null) break;

        final fileSize = await result.length();
        if (fileSize <= 1024 * 1024) {
          compressedFile = File(result.path);
          break;
        }

        quality -= 10;
      }

      return compressedFile;
    } catch (e) {
      AppLogger.error('Compression error', tag: 'VehicleReg', error: e);
      return null;
    }
  }

  Future<void> _pickImages(String type) async {
    final startTime = DateTime.now();
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);

    if (pickedFiles.isEmpty) return;

    await _logEvent('images_picked', parameters: {
      'type': type,
      'count': pickedFiles.length,
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Compressing images...'),
              ],
            ),
          ),
        ),
      ),
    );

    final compressedImages = <File>[];
    for (var pickedFile in pickedFiles) {
      final compressed = await _compressImage(File(pickedFile.path));
      if (compressed != null) {
        compressedImages.add(compressed);
      }
    }

    if (mounted) {
      Navigator.of(context).pop();

      setState(() {
        _imageGroups[type]!.addAll(compressedImages);
      });

      _showSnackBar('${compressedImages.length} images added successfully');

      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      await _logEvent('images_compressed', parameters: {
        'type': type,
        'count': compressedImages.length,
        'processing_time_ms': processingTime,
      });
    }
  }

  void _removeImage(String type, int index) {
    setState(() {
      _imageGroups[type]!.removeAt(index);
    });
    _logEvent('image_removed', parameters: {'type': type});
  }

  // FORM SUBMISSION
  Future<void> _submitForm() async {
    if (isOffline) {
      _showSnackBar('No internet connection. Please try again when online.', isError: true);
      return;
    }

    if (latitude == null || longitude == null) {
      _showSnackBar('Please set your location before submitting', isError: true);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', isError: true);
      await _logEvent('validation_failed');
      return;
    }

    // Validate new date fields
    if (_pucValidUptoDate == null) {
      _showSnackBar('Please select PUC valid upto date', isError: true);
      return;
    }
    if (_insuranceValidUptoDate == null) {
      _showSnackBar('Please select Insurance valid upto date', isError: true);
      return;
    }
    if (_licenseValidUptoDate == null) {
      _showSnackBar('Please select Driving License valid upto date', isError: true);
      return;
    }

    if (_imageGroups['vehicle']!.isEmpty) {
      _showSnackBar('Please upload at least one vehicle image', isError: true);
      await _logEvent('validation_failed', parameters: {'reason': 'no_vehicle_images'});
      return;
    }

    // Check duplicate registration
final duplicateResult = await _vehicleService.isRegistrationNumberExists(
    registrationController.text);
final isDuplicate = duplicateResult.when(
  success: (exists) => exists,
  failure: (e) {
    _showSnackBar('Could not verify registration: ${e.message}', isError: true);
    return true; // Treat as duplicate on error to prevent submission
  },
);
if (isDuplicate) {
  if (duplicateResult.isSuccess) {
    _showSnackBar('This registration number is already registered!', isError: true);
  }
  return;
}

setState(() {
  isSubmitting = true;
  _showUploadProgress = true;
});

final startTime = DateTime.now();

try {
  // Upload images using service
  final uploadResult = await _vehicleService.uploadVehicleImages(
    images: _imageGroups['vehicle']!,
    userId: widget.userId,
    onProgress: (progress, type) {
      if (mounted) {
        setState(() {
          _uploadProgress['overall'] = progress;
          _uploadProgress[type] = progress;
        });
      }
    },
  );

  if (uploadResult.isFailure) {
    _showSnackBar(uploadResult.exceptionOrNull?.message ?? 'Failed to upload images', isError: true);
    setState(() {
      isSubmitting = false;
      _showUploadProgress = false;
    });
    return;
  }

  final vehicleImageUrls = uploadResult.dataOrNull!;

  // Prepare location data
  final locationData = {
    'latitude': latitude,
    'longitude': longitude,
    'address': locationAddress,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'geopoint': GeoPoint(latitude!, longitude!),
    'timestamp': FieldValue.serverTimestamp(),
  };

  // Prepare vehicle details WITH NEW PASSENGER CAPACITY FIELD
  final vehicleDetails = {
    'category': selectedVehicleCategory,
    'brand': selectedBrand,
    'model': selectedModel,
    'color': selectedColor,
    'year': yearController.text,
    'registrationNumber': registrationController.text.toUpperCase(),
    'seatingCapacity': int.parse(seatingController.text),
    'maxPassengers': int.parse(_passengerCapacityController.text), // NEW FIELD
    'isAC': _isACVariant,
    'pucValidUpto': Timestamp.fromDate(_pucValidUptoDate!),
    'insuranceValidUpto': Timestamp.fromDate(_insuranceValidUptoDate!),
  };

  // Register vehicle using service
  final registerResult = await _vehicleService.registerVehicle(
    userId: widget.userId,
    locationData: locationData,
    vehicleDetails: vehicleDetails,
    vehicleImageUrls: vehicleImageUrls,
  );

  if (registerResult.isFailure) {
    _showSnackBar(registerResult.exceptionOrNull?.message ?? 'Failed to register vehicle', isError: true);
    setState(() {
      isSubmitting = false;
      _showUploadProgress = false;
    });
    return;
  }

  final vehicleId = registerResult.dataOrNull!;

  // Update user license using service
  final licenseResult = await _vehicleService.updateUserLicenseDetails(
    userId: widget.userId,
    licenseNumber: _licenseNumberController.text.trim(),
    licenseValidUpto: _licenseValidUptoDate!,
  );

  if (licenseResult.isFailure) {
    // Log but don't fail - vehicle is already registered
    await _logEvent('license_update_failed', parameters: {
      'error': licenseResult.exceptionOrNull?.message,
    });
  }

  final submissionTime = DateTime.now().difference(startTime).inMilliseconds;
  await _logEvent('vehicle_registered', parameters: {
    'category': selectedVehicleCategory,
    'brand': selectedBrand,
    'city': city,
    'state': state,
    'total_images': _imageGroups['vehicle']!.length,
    'submission_time_ms': submissionTime,
    'vehicle_id': vehicleId,
  });

  if (mounted) {
    _showSnackBar(
      'Vehicle registered successfully! Awaiting approval.',
      isSuccess: true,
    );
    context.go('/dashboard?userId=${widget.userId}');
  }
} catch (e) {
  _showSnackBar('Failed to register vehicle: $e', isError: true);
  await _logEvent('registration_failed', parameters: {
    'error': e.toString(),
  });
} finally {
  if (mounted) {
    setState(() {
      isSubmitting = false;
      _showUploadProgress = false;
      _uploadProgress.clear();
    });
  }
}

  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : (isSuccess ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
                  context.go('/dashboard?userId=${widget.userId}');
          },
        ),
        title: const Text(
          'Vehicle Registration',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isOffline)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: const Text(
                  'Offline',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.orange,
                avatar: const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 20),
                _buildLocationCard(),
                const SizedBox(height: 24),
                _buildVehicleDetailsCard(),
                const SizedBox(height: 24),
                _buildNewFieldsCard(), // NEW FIELDS CARD
                const SizedBox(height: 24),
                _buildVehiclePhotoCard(), // ONLY VEHICLE PHOTOS
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_showUploadProgress) _buildUploadProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Register Your Vehicle',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Start by setting your location, then fill in vehicle details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Icon(
                Icons.location_on,
                size: 150,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Location',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Required for nearby search',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isLoadingLocation)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Detecting your location...',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (latitude != null && longitude != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent[400],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Location Set',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            locationAddress ?? 'Address not available',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Lat: ${latitude!.toStringAsFixed(4)}, Lng: ${longitude!.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (locationPermissionDenied)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange[200],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Location permission denied. Please use manual entry.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No location set. Please detect or enter manually.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 16),
                  if (!useManualAddress)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoadingLocation || isOffline
                                ? null
                                : _getCurrentLocation,
                            icon: const Icon(Icons.my_location, size: 20),
                            label: const Text(
                              'Use Current Location',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isOffline
                                ? null
                                : () {
                              setState(() {
                                useManualAddress = true;
                              });
                            },
                            icon: const Icon(Icons.edit_location_alt, size: 20),
                            label: const Text(
                              'Enter Address Manually',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          key: const ValueKey('google_places_container'),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: GooglePlaceAutoCompleteTextField(
                            textEditingController: _manualAddressController,
                            googleAPIKey: googleApiKey,
                            focusNode: _searchFocusNode,
                            inputDecoration: InputDecoration(
                              hintText: 'Search for your location...',
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.blue[700],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            debounceTime: 600,
                            countries: const ["in"],
                            isLatLngRequired: false,
                            getPlaceDetailWithLatLng: (Prediction prediction) {
                              onPlaceSelected(prediction);
                            },
                            itemClick: (Prediction prediction) {
                              _manualAddressController.text = prediction.description ?? '';
                              _manualAddressController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                        offset: prediction.description?.length ?? 0),
                                  );
                            },
                            itemBuilder: (context, index, Prediction prediction) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.blue[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        prediction.description ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            seperatedBuilder: const Divider(height: 0),
                            isCrossBtnShown: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                useManualAddress = false;
                                _manualAddressController.clear();
                                _searchFocusNode.unfocus();
                              });
                            },
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text(
                              'Back to Auto-detect',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Icon(Icons.directions_car, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Vehicle Details',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your vehicle information',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Vehicle Type
            _buildSectionHeader('Vehicle Type'),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Vehicle Category',
              value: selectedVehicleCategory,
              items: const ['private', 'commercial'],
              onChanged: (value) {
                setState(() {
                  selectedVehicleCategory = value;
                  updateBrandsAndModels();
                });
              },
              displayText: (item) => item[0].toUpperCase() + item.substring(1),
            ),
            const SizedBox(height: 24),

            // Section: Make & Model
            _buildSectionHeader('Make & Model'),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Brand',
              value: selectedBrand,
              items: brands,
              onChanged: brands.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        selectedBrand = value;
                        updateModels();
                      });
                    },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Model',
              value: selectedModel,
              items: models,
              onChanged: models.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        selectedModel = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Color',
                    value: selectedColor,
                    items: colors,
                    onChanged: (value) {
                      setState(() {
                        selectedColor = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: yearController,
                    label: 'Year',
                    hint: '2024',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final year = int.tryParse(value);
                      if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                        return 'Invalid year';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section: Capacity
            _buildSectionHeader('Seating Capacity'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: seatingController,
                    label: 'Total Seats',
                    hint: '5',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (int.tryParse(value) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _passengerCapacityController,
                    label: 'Max Passengers',
                    hint: '4',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final passengers = int.tryParse(value);
                      if (passengers == null || passengers < 1) return 'Invalid';
                      final seating = int.tryParse(seatingController.text);
                      if (seating != null && passengers > seating) {
                        return 'Cannot exceed seats';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section: Registration
            _buildSectionHeader('Registration'),
            const SizedBox(height: 12),
            TextFormField(
              controller: registrationController,
              decoration: InputDecoration(
                labelText: 'Registration Number',
                hintText: 'WB-01-AB-1234',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                prefixIcon: const Icon(Icons.credit_card),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final formatted = _formatRegistrationNumber(newValue.text);
                  return TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }),
                LengthLimitingTextInputFormatter(13),
              ],
              validator: _validateRegistrationNumber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildNewFieldsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Icon(Icons.description, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Document & License Details',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter vehicle documents and driver license information',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Vehicle Features
            _buildSectionHeader('Vehicle Features'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CheckboxListTile(
                title: const Text('AC Variant'),
                subtitle: const Text('Check if vehicle has AC'),
                value: _isACVariant,
                onChanged: (value) {
                  setState(() {
                    _isACVariant = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 24),

            // Section: Vehicle Documents
            _buildSectionHeader('Vehicle Documents'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectDate(context, 'puc'),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'PUC Valid Upto *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _pucValidUptoDate != null
                      ? DateFormat('dd MMM yyyy').format(_pucValidUptoDate!)
                      : 'Select Date',
                  style: TextStyle(
                    color: _pucValidUptoDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectDate(context, 'insurance'),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Insurance Valid Upto *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _insuranceValidUptoDate != null
                      ? DateFormat('dd MMM yyyy').format(_insuranceValidUptoDate!)
                      : 'Select Date',
                  style: TextStyle(
                    color: _insuranceValidUptoDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section: Driver License
            _buildSectionHeader('Driver License'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _licenseNumberController,
              label: 'Driving License Number *',
              hint: 'e.g., WB1220190012345',
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Driving license number is required';
                }
                if (value.length < 10) {
                  return 'Invalid license number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectDate(context, 'license'),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'License Valid Upto *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _licenseValidUptoDate != null
                      ? DateFormat('dd MMM yyyy').format(_licenseValidUptoDate!)
                      : 'Select Date',
                  style: TextStyle(
                    color: _licenseValidUptoDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ONLY VEHICLE PHOTOS
  Widget _buildVehiclePhotoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Vehicle Photos',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload clear photos of your vehicle. Other documents can be uploaded later.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            _buildImageSection('Vehicle Photos', 'vehicle', Icons.directions_car),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String label, String type, IconData icon) {
    final images = _imageGroups[type]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${images.length} files',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (images.isNotEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(images[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeImage(type, index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: isOffline ? null : () => _pickImages(type),
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(images.isEmpty ? 'Add Photos' : 'Add More'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    String Function(String)? displayText,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem<String>(
        value: item,
        child: Text(displayText?.call(item) ?? item),
      ))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: isSubmitting || isOffline ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: isSubmitting
          ? const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : Text(
        isOffline ? 'Offline - Cannot Submit' : 'Submit Registration',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildUploadProgressOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Uploading Images...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: _uploadProgress['overall'] ?? 0,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                ),
                const SizedBox(height: 12),
                Text(
                  '${((_uploadProgress['overall'] ?? 0) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
