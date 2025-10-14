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

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadCatalogData();
    _loadDraft();
    _logScreenView();
    _setupAutoSave();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _registrationController.dispose();
    _seatingController.dispose();
    _scrollController.dispose();
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

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        isOffline = result == ConnectivityResult.none;
      });

      if (!isOffline && mounted) {
        _showSnackBar('Back online! You can now submit your registration.');
      }
    });
  }

  // ============ OFFLINE SUPPORT - DRAFT SAVING ============
  void _setupAutoSave() {
    // Listen to text field changes
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

        // Check if draft is recent (within 7 days)
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

      // Try cache first
      try {
        doc = await FirebaseFirestore.instance
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.cache));
        if (!doc.exists) doc = null;
      } catch (e) {
        doc = null;
      }

      // Fetch from server if cache miss
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

    final categoryData =
    catalogData?[selectedVehicleCategory] as Map<String, dynamic>?;
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
    if (selectedVehicleCategory == null ||
        selectedBrand == null ||
        catalogData == null) {
      setState(() {
        models = [];
        selectedModel = null;
      });
      return;
    }

    final categoryData =
    catalogData?[selectedVehicleCategory] as Map<String, dynamic>?;
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
      _saveDraft(); // Save draft after adding images

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

      // Upload all images with progress tracking
      for (var entry in _imageGroups.entries) {
        for (var image in entry.value) {
          final ref = storage.ref().child(
              'vehicles/${widget.userId}/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg');

          final uploadTask = ref.putFile(image);

          // Track upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            setState(() {
              _uploadProgress[entry.key] =
                  snapshot.bytesTransferred / snapshot.totalBytes;
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

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance.collection('vehicles').add({
        'userId': widget.userId,
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

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
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
                const SizedBox(height: 16),
                const Text(
                  'Please wait...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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
          'Fill in the details below to register your vehicle',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        if (!isOffline) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Auto-saving draft',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
              items: ['private', 'commercial'],
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
                      if (year == null ||
                          year < 1900 ||
                          year > DateTime.now().year + 1) {
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
              validator: (value) =>
              value == null || value.isEmpty ? 'Required' : null,
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