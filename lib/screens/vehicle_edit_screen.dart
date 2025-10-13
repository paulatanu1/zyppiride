import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      // Load catalog data
      final catalogDoc = await FirebaseFirestore.instance
          .collection('vehicleCatalog')
          .doc('india2025')
          .get();

      // Load vehicle data
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
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
        catalogData == null) return;

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
      debugPrint('Compression error: $e');
      return null;
    }
  }

  Future<void> _pickImages(String type) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);

    if (pickedFiles.isEmpty) return;

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

      // Upload new images
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

      // Delete marked images from storage
      for (var entry in _imagesToDelete.entries) {
        for (var imageUrl in entry.value) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            debugPrint('Failed to delete image: $e');
          }
        }
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('vehicles')
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
                setState(() {
                  selectedVehicleCategory = value;
                  selectedBrand = null;
                  selectedModel = null;
                });
                _updateBrandsAndModels();
              },
              displayText: (item) =>
              item[0].toUpperCase() + item.substring(1),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Brand *',
              value: selectedBrand,
              items: brands,
              onChanged: brands.isEmpty
                  ? null
                  : (value) {
                setState(() {
                  selectedBrand = value;
                  selectedModel = null;
                });
                _updateModels();
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Model *',
              value: selectedModel,
              items: models,
              onChanged: models.isEmpty
                  ? null
                  : (value) => setState(() => selectedModel = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Color *',
              value: selectedColor,
              items: colors,
              onChanged: (value) => setState(() => selectedColor = value),
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
                  'Documents',
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
              'Add or remove images. New images will be compressed automatically.',
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
    final existingImages = _existingImageUrls[type]!;
    final newImages = _newImages[type]!;
    final totalImages = existingImages.length + newImages.length;

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
              '$totalImages file(s)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalImages > 0)
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing images from server
                ...existingImages.map((imageUrl) {
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(type, imageUrl),
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
                }),
                // New images from device
                ...newImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 2),
                          image: DecorationImage(
                            image: FileImage(image),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removeNewImage(type, index),
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
                }),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _pickImages(type),
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(totalImages == 0 ? 'Add Photos' : 'Add More'),
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
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSubmitting
                ? null
                : () {
              context.go(
                '/vehicle-view?userId=${widget.userId}&vehicleId=${widget.vehicleId}',
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _submitForm,
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
                : const Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ],
    );
  }
}