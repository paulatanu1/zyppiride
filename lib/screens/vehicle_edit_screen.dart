import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/constants/test_mode.dart';
import '../core/utils/app_logger.dart';

class VehicleEditScreen extends StatefulWidget {
  final String userId;
  final String vehicleId;

  const VehicleEditScreen({
    super.key,
    required this.userId,
    required this.vehicleId,
  });

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _analytics = FirebaseAnalytics.instance;

  // Existing image URLs from server
  final Map<String, List<String>> _existingImageUrls = {
    'vehicle': [],
    'rc': [],
    'license': [],
    'insurance': [],
    'puc': [],
  };

  // New images to upload
  final Map<String, List<File>> _newImages = {
    'vehicle': [],
    'rc': [],
    'license': [],
    'insurance': [],
    'puc': [],
  };

  // Images marked for deletion
  final Map<String, List<String>> _imagesToDelete = {
    'vehicle': [],
    'rc': [],
    'license': [],
    'insurance': [],
    'puc': [],
  };

  // Upload progress
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
  Map<String, dynamic>? catalogData;
  Map<String, dynamic>? vehicleData;

  @override
  void initState() {
    super.initState();
    _loadData();
    _logScreenView();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _registrationController.dispose();
    _seatingController.dispose();
    super.dispose();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'VehicleEdit',
      screenClass: 'VehicleEditScreen',
    );
  }

  Future<void> _loadData() async {
    try {
      final catalogDoc = await FirebaseFirestore.instance
          .collection('vehicleCatalog')
          .doc('india2025')
          .get();

      final vehicleDoc = await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .doc(widget.vehicleId)
          .get();

      if (catalogDoc.exists && vehicleDoc.exists && mounted) {
        catalogData = catalogDoc.data();
        vehicleData = vehicleDoc.data();

        final details = vehicleData!['vehicleDetails'] as Map<String, dynamic>;
        final documents = vehicleData!['documents'] as Map<String, dynamic>;

        setState(() {
          colors = List<String>.from(catalogData?['colors'] ?? []);

          selectedVehicleCategory = details['category'];
          selectedBrand = details['brand'];
          selectedModel = details['model'];
          selectedColor = details['color'];
          _yearController.text = details['year']?.toString() ?? '';
          _registrationController.text = details['registrationNumber'] ?? '';
          _seatingController.text = details['seatingCapacity']?.toString() ?? '';

          _existingImageUrls['vehicle'] =
          List<String>.from(documents['vehicleImages'] ?? []);
          _existingImageUrls['rc'] =
          List<String>.from(documents['rcImages'] ?? []);
          _existingImageUrls['license'] =
          List<String>.from(documents['licenseImages'] ?? []);
          _existingImageUrls['insurance'] =
          List<String>.from(documents['insuranceImages'] ?? []);
          _existingImageUrls['puc'] =
          List<String>.from(documents['pucImages'] ?? []);

          isLoading = false;
        });

        _updateBrandsAndModels();
        _updateModels();
      } else {
        setState(() => isLoading = false);
        _showSnackBar('Failed to load vehicle data', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _updateBrandsAndModels() {
    if (selectedVehicleCategory == null || catalogData == null) return;

    final categoryData =
    catalogData?[selectedVehicleCategory] as Map<String, dynamic>?;
    if (categoryData != null) {
      setState(() {
        brands = categoryData.keys.map((e) => e.toString()).toList();
      });
    }
  }

  void _updateModels() {
    if (selectedVehicleCategory == null ||
        selectedBrand == null ||
        catalogData == null) {return;}

    final categoryData =
    catalogData?[selectedVehicleCategory] as Map<String, dynamic>?;
    final brandData = categoryData?[selectedBrand];

    if (brandData is Map) {
      setState(() {
        models = brandData.keys.map((e) => e.toString()).toList();
      });
    } else if (brandData is List) {
      setState(() {
        models = List<String>.from(brandData);
      });
    }
  }

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
      AppLogger.error('Compression error', tag: 'VehicleEdit', error: e);
      return null;
    }
  }

  Future<void> _pickImages(String type) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);

    if (pickedFiles.isEmpty) return;

    if (!mounted) return;
    unawaited(showDialog(
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
    ));

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
        _newImages[type]!.addAll(compressedImages);
      });
      _showSnackBar('${compressedImages.length} image(s) added');
    }
  }

  void _removeExistingImage(String type, String imageUrl) {
    setState(() {
      _existingImageUrls[type]!.remove(imageUrl);
      _imagesToDelete[type]!.add(imageUrl);
    });
  }

  void _removeNewImage(String type, int index) {
    setState(() {
      _newImages[type]!.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }

    final totalVehicleImages =
        _existingImageUrls['vehicle']!.length + _newImages['vehicle']!.length;
    if (totalVehicleImages == 0) {
      _showSnackBar('Please upload at least one vehicle image', isError: true);
      return;
    }

    setState(() {
      isSubmitting = true;
      _showUploadProgress = true;
    });

    try {
      final storage = FirebaseStorage.instance;
      int totalNewImages = _newImages.values.fold<int>(
        0,
            (int sum, List<File> list) => sum + list.length,
      );
      int uploadedImages = 0;

      for (var entry in _newImages.entries) {
        for (var image in entry.value) {
          final ref = storage.ref().child(
              'vehicles/${widget.userId}/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg');

          final uploadTask = ref.putFile(image);

          uploadTask.snapshotEvents.listen((snapshot) {
            setState(() {
              _uploadProgress[entry.key] =
                  snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });

          await uploadTask;
          final url = await ref.getDownloadURL();
          _existingImageUrls[entry.key]!.add(url);

          uploadedImages++;
          if (mounted) {
            setState(() {
              _uploadProgress['overall'] = totalNewImages > 0
                  ? uploadedImages / totalNewImages
                  : 0;
            });
          }
        }
      }

      for (var entry in _imagesToDelete.entries) {
        for (var imageUrl in entry.value) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            AppLogger.error('Failed to delete image', tag: 'VehicleEdit', error: e);
          }
        }
      }

      await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .doc(widget.vehicleId)
          .update({
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
          'vehicleImages': _existingImageUrls['vehicle'],
          'rcImages': _existingImageUrls['rc'],
          'licenseImages': _existingImageUrls['license'],
          'insuranceImages': _existingImageUrls['insurance'],
          'pucImages': _existingImageUrls['puc'],
        },
        'documentStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _analytics.logEvent(
        name: 'vehicle_updated',
        parameters: {
          'vehicle_id': widget.vehicleId,
          'new_images_uploaded': totalNewImages,
          'images_deleted': _imagesToDelete.values.fold<int>(
            0,
                (int sum, List<String> list) => sum + list.length,
          ),
        },
      );

      if (mounted) {
        _showSnackBar('Vehicle updated successfully!', isSuccess: true);
        context.go(
          '/vehicle-view?userId=${widget.userId}&vehicleId=${widget.vehicleId}',
        );
      }
    } catch (e) {
      _showSnackBar('Failed to update vehicle: $e', isError: true);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            '/vehicle-view?userId=${widget.userId}&vehicleId=${widget.vehicleId}',
          ),
        ),
        title: const Text(
          'Edit Vehicle',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
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
                  'Updating Vehicle...',
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
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
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

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Edit Vehicle Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Update your vehicle information below',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ------------------ MODERN DROPDOWN ------------------
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    String Function(String)? displayText,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
      dropdownColor: Colors.grey[50],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Colors.black87,
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            displayText?.call(item) ?? item,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
    );
  }

  // ------------------ MODERN TEXT FIELD ------------------
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
    );
  }

  Widget _buildVehicleDetailsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDropdown(
              label: 'Vehicle Category',
              value: selectedVehicleCategory,
              items: catalogData?.keys.toList() ?? [],
              onChanged: (val) {
                setState(() {
                  selectedVehicleCategory = val;
                  selectedBrand = null;
                  selectedModel = null;
                  brands.clear();
                  models.clear();
                });
                _updateBrandsAndModels();
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Brand',
              value: selectedBrand,
              items: brands,
              onChanged: (val) {
                setState(() {
                  selectedBrand = val;
                  selectedModel = null;
                  models.clear();
                });
                _updateModels();
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Model',
              value: selectedModel,
              items: models,
              onChanged: (val) {
                setState(() => selectedModel = val);
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Color',
              value: selectedColor,
              items: colors,
              onChanged: (val) => setState(() => selectedColor = val),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Year of Manufacture',
              controller: _yearController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Registration Number',
              controller: _registrationController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Seating Capacity',
              controller: _seatingController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDocumentUploadRow('Vehicle Images', 'vehicle'),
            const SizedBox(height: 16),
            _buildDocumentUploadRow('RC Images', 'rc'),
            const SizedBox(height: 16),
            _buildDocumentUploadRow('License Images', 'license'),
            const SizedBox(height: 16),
            _buildDocumentUploadRow('Insurance Images', 'insurance'),
            const SizedBox(height: 16),
            _buildDocumentUploadRow('PUC Images', 'puc'),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadRow(String title, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._existingImageUrls[type]!.map(
                  (url) => Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeExistingImage(type, url),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            ..._newImages[type]!.asMap().entries.map(
                  (entry) => Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      entry.value,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeNewImage(type, entry.key),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _pickImages(type),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: const Icon(Icons.add_a_photo, color: Colors.grey, size: 32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.blue[700],
        ),
        child: Text(
          isSubmitting ? 'Updating...' : 'Update Vehicle',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
