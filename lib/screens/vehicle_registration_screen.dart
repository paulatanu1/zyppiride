import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

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

  // Image lists
  final Map<String, List<File>> _imageGroups = {
    'vehicle': [],
    'rc': [],
    'license': [],
    'insurance': [],
    'puc': [],
  };

  // Upload progress tracking
  final Map<String, double> _uploadProgress = {};
  bool _showUploadProgress = false;

  // Location tracking
  double? _latitude;
  double? _longitude;
  String? _locationAddress;
  String? _city;
  String? _state;
  String? _postalCode;
  bool _isLoadingLocation = false;
  bool _locationPermissionDenied = false;
  bool _useManualAddress = false;

  // Form fields
  String? selectedVehicleCategory;
  String? selectedBrand;
  String? selectedModel;
  String? selectedColor;
  final _yearController = TextEditingController();
  final _registrationController = TextEditingController();
  final _seatingController = TextEditingController();

  List<String> colors = [];
  List<String> brands = [];
  List<String> models = [];

  bool isLoading = true;
  bool isSubmitting = false;
  bool isOffline = false;
  Map<String, dynamic>? catalogData;

  // Draft save timer
  DateTime _lastSaveTime = DateTime.now();
  static const _autoSaveInterval = Duration(seconds: 30);

  // Google Places API Key - REPLACE WITH YOUR KEY
  static const String _googleApiKey = 'AIzaSyABUF7GCEM6h1n3isugLj2qOEySpTtxd1I';

  // Key to rebuild Google Places widget
  int _googlePlacesKey = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadCatalogData();
    _loadDraft();
    _logScreenView();
    _setupAutoSave();
    // Auto-fetch location on init
    Future.delayed(const Duration(milliseconds: 500), () {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _yearController.dispose();
    _registrationController.dispose();
    _seatingController.dispose();
    _scrollController.dispose();
    _manualAddressController.dispose();
    super.dispose();
  }

  // ============ ANALYTICS ============
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

  // ============ CONNECTIVITY ============
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOffline = connectivityResult == ConnectivityResult.none;
    });

    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        isOffline = result == ConnectivityResult.none;
      });

      if (!isOffline && mounted) {
        _showSnackBar('Back online! You can now submit your registration.');
      }
    });
  }

  // ============ LOCATION SERVICES ============
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationPermissionDenied = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
        });
        _showSnackBar('Location services are disabled. Please enable them in settings.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionDenied = true;
          });
          _showSnackBar('Location permission denied. Please enter address manually.', isError: true);
          await _logEvent('location_permission_denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
        });
        _showSnackBar('Location permissions are permanently denied. Please enable in settings.', isError: true);
        await _logEvent('location_permission_denied_forever');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _city = place.locality ?? place.subLocality;
          _state = place.administrativeArea;
          _postalCode = place.postalCode;
          _locationAddress = _formatAddress(place);
          _isLoadingLocation = false;
          _useManualAddress = false;
        });
        _showSnackBar('Location detected successfully!', isSuccess: true);
        _saveDraft();
        await _logEvent('location_detected', parameters: {
          'city': _city,
          'state': _state,
        });
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
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

  void _onPlaceSelected(Prediction prediction) async {
    setState(() => _isLoadingLocation = true);

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
            _latitude = location.latitude;
            _longitude = location.longitude;
            _city = place.locality ?? place.subLocality;
            _state = place.administrativeArea;
            _postalCode = place.postalCode;
            _locationAddress = prediction.description ?? _formatAddress(place);
            _isLoadingLocation = false;
            _useManualAddress = false;
          });
          _manualAddressController.clear();
          _showSnackBar('Location selected successfully!', isSuccess: true);
          _saveDraft();
          await _logEvent('manual_location_selected', parameters: {
            'city': _city,
            'state': _state,
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      _showSnackBar('Failed to get coordinates for selected place: $e', isError: true);
    }
  }

  // ============ OFFLINE SUPPORT - DRAFT SAVING ============
  void _setupAutoSave() {
    _yearController.addListener(_scheduleAutoSave);
    _registrationController.addListener(_scheduleAutoSave);
    _seatingController.addListener(_scheduleAutoSave);
  }

  void _scheduleAutoSave() {
    final now = DateTime.now();
    if (now.difference(_lastSaveTime) > _autoSaveInterval) {
      _saveDraft();
      _lastSaveTime = now;
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = {
        'selectedVehicleCategory': selectedVehicleCategory,
        'selectedBrand': selectedBrand,
        'selectedModel': selectedModel,
        'selectedColor': selectedColor,
        'year': _yearController.text,
        'registrationNumber': _registrationController.text,
        'seatingCapacity': _seatingController.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'locationAddress': _locationAddress,
        'city': _city,
        'state': _state,
        'imageCount': {
          'vehicle': _imageGroups['vehicle']!.length,
          'rc': _imageGroups['rc']!.length,
          'license': _imageGroups['license']!.length,
          'insurance': _imageGroups['insurance']!.length,
          'puc': _imageGroups['puc']!.length,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString('vehicle_draft_${widget.userId}', json.encode(draftData));

      await _logEvent('draft_saved', parameters: {
        'has_location': _latitude != null,
        'has_vehicle_images': _imageGroups['vehicle']!.isNotEmpty,
        'total_images': _imageGroups.values.fold(0, (sum, list) => sum + list.length),
      });
    } catch (e) {
      debugPrint('Failed to save draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftString = prefs.getString('vehicle_draft_${widget.userId}');

      if (draftString != null) {
        final draftData = json.decode(draftString) as Map<String, dynamic>;

        final timestamp = DateTime.parse(draftData['timestamp'] as String);
        if (DateTime.now().difference(timestamp).inDays <= 7) {
          final shouldRestore = await _showRestoreDraftDialog();

          if (shouldRestore && mounted) {
            setState(() {
              selectedVehicleCategory = draftData['selectedVehicleCategory'] as String?;
              selectedBrand = draftData['selectedBrand'] as String?;
              selectedModel = draftData['selectedModel'] as String?;
              selectedColor = draftData['selectedColor'] as String?;
              _yearController.text = draftData['year'] as String? ?? '';
              _registrationController.text = draftData['registrationNumber'] as String? ?? '';
              _seatingController.text = draftData['seatingCapacity'] as String? ?? '';
              _latitude = draftData['latitude'] as double?;
              _longitude = draftData['longitude'] as double?;
              _locationAddress = draftData['locationAddress'] as String?;
              _city = draftData['city'] as String?;
              _state = draftData['state'] as String?;
            });

            _showSnackBar('Draft restored successfully');
            await _logEvent('draft_restored');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load draft: $e');
    }
  }

  Future<bool> _showRestoreDraftDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Draft?'),
        content: const Text('You have a saved draft. Would you like to restore it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('vehicle_draft_${widget.userId}');
    } catch (e) {
      debugPrint('Failed to clear draft: $e');
    }
  }

  // ============ CATALOG DATA ============
  Future<void> _loadCatalogData() async {
    final startTime = DateTime.now();

    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;

      try {
        doc = await FirebaseFirestore.instance
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.cache));
        if (!doc.exists) doc = null;
      } catch (e) {
        doc = null;
      }

      if (doc == null && !isOffline) {
        doc = await FirebaseFirestore.instance
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.server));
      }

      if (doc?.exists == true && mounted) {
        setState(() {
          catalogData = doc!.data();
          colors = List<String>.from(catalogData?['colors'] ?? []);
          isLoading = false;
        });

        final loadTime = DateTime.now().difference(startTime).inMilliseconds;
        await _logEvent('catalog_loaded', parameters: {
          'load_time_ms': loadTime,
          'source': doc?.metadata.isFromCache == true ? 'cache' : 'server',
        });
      } else {
        setState(() => isLoading = false);
        _showSnackBar('Vehicle catalog not found', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Failed to load catalog: $e', isError: true);
      await _logEvent('catalog_load_error', parameters: {'error': e.toString()});
    }
  }

  void _updateBrandsAndModels() {
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

  void _updateModels() {
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

  // ============ IMAGE HANDLING ============
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      int quality = 85;
      File? compressedFile;

      while (quality > 10) {
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
      debugPrint('Compression error: $e');
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
      _showSnackBar('${compressedImages.length} image(s) added successfully');
      _saveDraft();

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
    _saveDraft();
    _logEvent('image_removed', parameters: {'type': type});
  }

  // ============ FORM SUBMISSION ============
  Future<void> _submitForm() async {
    if (isOffline) {
      _showSnackBar('No internet connection. Please try again when online.', isError: true);
      return;
    }

    if (_latitude == null || _longitude == null) {
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

    if (_imageGroups['vehicle']!.isEmpty) {
      _showSnackBar('Please upload at least one vehicle image', isError: true);
      await _logEvent('validation_failed', parameters: {'reason': 'no_vehicle_images'});
      return;
    }

    setState(() {
      isSubmitting = true;
      _showUploadProgress = true;
    });

    final startTime = DateTime.now();

    try {
      final storage = FirebaseStorage.instance;
      final Map<String, List<String>> uploadedUrls = {
        'vehicle': [],
        'rc': [],
        'license': [],
        'insurance': [],
        'puc': [],
      };

      int totalImages = _imageGroups.values.fold(0, (sum, list) => sum + list.length);
      int uploadedImages = 0;

      for (var entry in _imageGroups.entries) {
        for (var image in entry.value) {
          final ref = storage.ref().child(
              'vehicles/${widget.userId}/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg');

          final uploadTask = ref.putFile(image);

          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            setState(() {
              _uploadProgress[entry.key] = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });

          await uploadTask;
          final url = await ref.getDownloadURL();
          uploadedUrls[entry.key]!.add(url);

          uploadedImages++;
          if (mounted) {
            setState(() {
              _uploadProgress['overall'] = uploadedImages / totalImages;
            });
          }
        }
      }

      final docRef = await FirebaseFirestore.instance.collection('vehicles').add({
        'userId': widget.userId,
        'location': {
          'latitude': _latitude,
          'longitude': _longitude,
          'address': _locationAddress,
          'city': _city,
          'state': _state,
          'postalCode': _postalCode,
          'geopoint': GeoPoint(_latitude!, _longitude!),
          'timestamp': FieldValue.serverTimestamp(),
        },
        'vehicleDetails': {
          'category': selectedVehicleCategory,
          'brand': selectedBrand,
          'model': selectedModel,
          'color': selectedColor,
          'year': _yearController.text,
          'registrationNumber': _registrationController.text.toUpperCase(),
          'seatingCapacity': int.parse(_seatingController.text),
        },
        'documents': {
          'vehicleImages': uploadedUrls['vehicle'],
          'rcImages': uploadedUrls['rc'],
          'licenseImages': uploadedUrls['license'],
          'insuranceImages': uploadedUrls['insurance'],
          'pucImages': uploadedUrls['puc'],
        },
        'documentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final submissionTime = DateTime.now().difference(startTime).inMilliseconds;

      await _logEvent('vehicle_registered', parameters: {
        'category': selectedVehicleCategory,
        'brand': selectedBrand,
        'city': _city,
        'state': _state,
        'total_images': totalImages,
        'submission_time_ms': submissionTime,
        'vehicle_id': docRef.id,
      });

      await _clearDraft();

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
        backgroundColor: isError
            ? Colors.red
            : isSuccess
            ? Colors.green
            : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============ UI WIDGETS ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _saveDraft();
            context.go('/dashboard?userId=${widget.userId}');
          },
        ),
        title: const Text(
          'Vehicle Registration',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
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
                _buildDocumentsCard(),
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
            color: Colors.blue.withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.1),
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
                          color: Colors.white.withOpacity(0.2),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                  if (_isLoadingLocation)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
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
                  else if (_latitude != null && _longitude != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
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
                            _locationAddress ?? 'Address not available',
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
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (_locationPermissionDenied)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
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
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
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
                  if (!_useManualAddress)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_isLoadingLocation || isOffline)
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
                              setState(() => _useManualAddress = true);
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
                            googleAPIKey: _googleApiKey,
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
                            isLatLngRequired: true,
                            getPlaceDetailWithLatLng: (Prediction prediction) {
                              _onPlaceSelected(prediction);
                            },
                            itemClick: (Prediction prediction) {
                              _manualAddressController.text = prediction.description ?? '';
                              _manualAddressController.selection = TextSelection.fromPosition(
                                TextPosition(offset: prediction.description?.length ?? 0),
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
                                _useManualAddress = false;
                                _manualAddressController.clear();
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

  Widget _buildVehicleDetailsCard() {
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
            const SizedBox(height: 20),
            _buildDropdown(
              label: 'Vehicle Category *',
              value: selectedVehicleCategory,
              items: const ['private', 'commercial'],
              onChanged: (value) {
                setState(() => selectedVehicleCategory = value);
                _updateBrandsAndModels();
                _saveDraft();
              },
              displayText: (item) => item[0].toUpperCase() + item.substring(1),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Brand *',
              value: selectedBrand,
              items: brands,
              onChanged: brands.isEmpty
                  ? null
                  : (value) {
                setState(() => selectedBrand = value);
                _updateModels();
                _saveDraft();
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Model *',
              value: selectedModel,
              items: models,
              onChanged: models.isEmpty
                  ? null
                  : (value) {
                setState(() => selectedModel = value);
                _saveDraft();
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Color *',
              value: selectedColor,
              items: colors,
              onChanged: (value) {
                setState(() => selectedColor = value);
                _saveDraft();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _yearController,
                    label: 'Year *',
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _seatingController,
                    label: 'Seating *',
                    hint: '5',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (int.tryParse(value) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registrationController,
              label: 'Registration Number *',
              hint: 'WB 01 AB 1234',
              textCapitalization: TextCapitalization.characters,
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsCard() {
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
                  'Upload Documents',
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
              'Images will be compressed to under 1MB automatically',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            _buildImageSection('Vehicle Photos *', 'vehicle', Icons.directions_car),
            const SizedBox(height: 16),
            _buildImageSection('RC Certificate', 'rc', Icons.description),
            const SizedBox(height: 16),
            _buildImageSection('Driving License', 'license', Icons.credit_card),
            const SizedBox(height: 16),
            _buildImageSection('Insurance', 'insurance', Icons.security),
            const SizedBox(height: 16),
            _buildImageSection('PUC Certificate', 'puc', Icons.verified),
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
              '${images.length} file(s)',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      value: value,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: (isSubmitting || isOffline) ? null : _submitForm,
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
}