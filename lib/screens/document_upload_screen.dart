import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/constants/test_mode.dart';
import '../core/utils/app_logger.dart';
import '../main.dart' show scaffoldMessengerKey;

class DocumentUploadScreen extends StatefulWidget {
  final String userId;

  const DocumentUploadScreen({super.key, required this.userId});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final _analytics = FirebaseAnalytics.instance;

  String? selectedVehicleId;
  Map<String, dynamic>? selectedVehicleData;

  final Map<String, List<File>> _documentGroups = {
    'rc': [],
    'license': [],
    'insurance': [],
    'puc': [],
  };

  final Map<String, double> _uploadProgress = {};
  bool _isUploading = false;
  bool _showUploadProgress = false;
  bool _isLoadingVehicles = false;

  @override
  void initState() {
    super.initState();
    _logScreenView();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'DocumentUpload',
      screenClass: 'DocumentUploadScreen',
    );
  }

  Future<void> _logEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: parameters?.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  bool _canEditDocuments(String? documentStatus) {
    return documentStatus == null ||
        documentStatus == 'pending' ||
        documentStatus == 'rejected' ||
        documentStatus == 'submitted';
  }

  bool _hasExistingDocuments() {
    final documents = selectedVehicleData?['documents'] as Map<String, dynamic>?;
    if (documents == null) return false;

    return (documents['rcImages'] as List?)?.isNotEmpty == true ||
        (documents['licenseImages'] as List?)?.isNotEmpty == true ||
        (documents['insuranceImages'] as List?)?.isNotEmpty == true ||
        (documents['pucImages'] as List?)?.isNotEmpty == true;
  }

  Future<void> _showVehicleSelectionSheet() async {
    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final vehiclesSnapshot = await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .where('userId', isEqualTo: widget.userId)
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      setState(() {
        _isLoadingVehicles = false;
      });

      if (vehiclesSnapshot.docs.isEmpty) {
        _showSnackBar('No vehicles found. Please register a vehicle first.', isError: true);
        return;
      }

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.directions_car, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Vehicle',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Choose vehicle to upload documents',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: vehiclesSnapshot.docs.length,
                    itemBuilder: (context, index) {
                      final vehicleDoc = vehiclesSnapshot.docs[index];
                      final vehicleData = vehicleDoc.data();
                      final vehicleDetails = vehicleData['vehicleDetails'] as Map<String, dynamic>?;
                      final documents = vehicleData['documents'] as Map<String, dynamic>?;
                      final documentStatus = vehicleData['documentStatus'] as String?;

                      final registrationNumber = vehicleDetails?['registrationNumber'] ?? 'N/A';
                      final brand = vehicleDetails?['brand'] ?? '';
                      final model = vehicleDetails?['model'] ?? '';
                      final color = vehicleDetails?['color'] ?? '';
                      final year = vehicleDetails?['year'] ?? '';

                      final hasDocuments = (documents?['rcImages'] as List?)?.isNotEmpty == true ||
                          (documents?['licenseImages'] as List?)?.isNotEmpty == true ||
                          (documents?['insuranceImages'] as List?)?.isNotEmpty == true ||
                          (documents?['pucImages'] as List?)?.isNotEmpty == true;

                      Color statusColor;
                      String statusText;
                      IconData statusIcon;

                      switch (documentStatus) {
                        case 'approved':
                          statusColor = Colors.green;
                          statusText = 'Approved';
                          statusIcon = Icons.check_circle;
                          break;
                        case 'rejected':
                          statusColor = Colors.red;
                          statusText = 'Rejected';
                          statusIcon = Icons.cancel;
                          break;
                        case 'submitted':
                          statusColor = Colors.blue;
                          statusText = 'Under Review';
                          statusIcon = Icons.hourglass_empty;
                          break;
                        default:
                          statusColor = Colors.orange;
                          statusText = hasDocuments ? 'Pending' : 'Not Uploaded';
                          statusIcon = Icons.pending;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selectedVehicleId == vehicleDoc.id
                                ? Colors.green
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedVehicleId = vehicleDoc.id;
                              selectedVehicleData = vehicleData;
                              _documentGroups.forEach((key, value) => value.clear());
                            });
                            Navigator.pop(context);
                            _showSnackBar('Vehicle selected: $registrationNumber', isSuccess: true);
                            _logEvent('vehicle_selected', parameters: {
                              'vehicle_id': vehicleDoc.id,
                              'registration_number': registrationNumber,
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade400, Colors.green.shade600],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        registrationNumber,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$brand $model',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.palette, size: 12, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              color,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            year,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              statusIcon,
                                              size: 12,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 10,
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedVehicleId == vehicleDoc.id)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingVehicles = false;
      });
      _showSnackBar('Failed to load vehicles: $e', isError: true);
    }
  }

  Future<void> _pickImage(String documentType) async {
    if (selectedVehicleId == null) {
      _showSnackBar('Please select a vehicle first', isError: true);
      return;
    }

    final documentStatus = selectedVehicleData?['documentStatus'] as String?;
    if (!_canEditDocuments(documentStatus)) {
      _showSnackBar('Documents are already approved. Contact support to make changes.', isError: true);
      return;
    }

    unawaited(showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.green),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera, documentType);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.green),
                  ),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery, documentType);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> _getImage(ImageSource source, String documentType) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _documentGroups[documentType]!.add(File(pickedFile.path));
        });
        _showSnackBar('Image added successfully', isSuccess: true);
        await _logEvent('document_image_added', parameters: {
          'document_type': documentType,
          'vehicle_id': selectedVehicleId,
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  void _removeImage(String type, int index) {
    setState(() {
      _documentGroups[type]!.removeAt(index);
    });
    _showSnackBar('Image removed', isSuccess: true);
    _logEvent('document_image_removed', parameters: {
      'document_type': type,
      'vehicle_id': selectedVehicleId,
    });
  }

  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
      path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      AppLogger.error('Compression error', tag: 'DocumentUpload', error: e);
      return file;
    }
  }

  void _viewDocuments() {
    final documents = selectedVehicleData?['documents'] as Map<String, dynamic>?;

    if (documents == null) {
      _showSnackBar('No documents found', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Uploaded Documents',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildViewDocumentSection('RC Book', documents['rcImages'] as List?),
                    _buildViewDocumentSection('License', documents['licenseImages'] as List?),
                    _buildViewDocumentSection('Insurance', documents['insuranceImages'] as List?),
                    _buildViewDocumentSection('PUC', documents['pucImages'] as List?),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewDocumentSection(String title, List? images) {
    if (images == null || images.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      color: Colors.grey[100],
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewAndEditDocuments() {
    final documents = selectedVehicleData?['documents'] as Map<String, dynamic>?;

    if (documents == null) {
      _showSnackBar('No documents found', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_document, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Manage Documents',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap the delete icon to remove a document',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildEditDocumentSection('RC Book', documents['rcImages'] as List?, 'rc'),
                    _buildEditDocumentSection('License', documents['licenseImages'] as List?, 'license'),
                    _buildEditDocumentSection('Insurance', documents['insuranceImages'] as List?, 'insurance'),
                    _buildEditDocumentSection('PUC', documents['pucImages'] as List?, 'puc'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditDocumentSection(String title, List? images, String type) {
    if (images == null || images.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${images.length} image${images.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          color: Colors.grey[100],
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _deleteExistingDocument(images[index], type, index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete,
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
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExistingDocument(String imageUrl, String type, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Document?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        content: const Text(
          'Are you sure you want to delete this document? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();

      final fieldName = type == 'rc' ? 'rcImages' :
      type == 'license' ? 'licenseImages' :
      type == 'insurance' ? 'insuranceImages' : 'pucImages';

      await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .doc(selectedVehicleId)
          .update({
        'documents.$fieldName': FieldValue.arrayRemove([imageUrl]),
      });

      setState(() {
        final documents = selectedVehicleData?['documents'] as Map<String, dynamic>?;
        if (documents != null && documents[fieldName] != null) {
          (documents[fieldName] as List).remove(imageUrl);
        }
      });

      if (!mounted) return;
      _showSnackBar('Document deleted successfully', isSuccess: true);
      if (!mounted) return;
      Navigator.pop(context);
      _viewAndEditDocuments();

    } catch (e) {
      _showSnackBar('Failed to delete document: $e', isError: true);
    }
  }

  Future<void> _uploadDocuments() async {
    if (selectedVehicleId == null) {
      _showSnackBar('Please select a vehicle first', isError: true);
      return;
    }

    final documentStatus = selectedVehicleData?['documentStatus'] as String?;
    if (!_canEditDocuments(documentStatus)) {
      _showSnackBar('Documents are already approved. Contact support to make changes.', isError: true);
      return;
    }

    if (_documentGroups['rc']!.isEmpty &&
        _documentGroups['license']!.isEmpty &&
        _documentGroups['insurance']!.isEmpty &&
        _documentGroups['puc']!.isEmpty) {
      _showSnackBar('Please add at least one document', isError: true);
      return;
    }

    // Guard: the Firestore rule checks request.auth.uid == resource.data.userId.
    // widget.userId comes from the route param and must match the live auth UID.
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null || authUid != widget.userId) {
      _showSnackBar('Session error — please log out and log in again.', isError: true);
      return;
    }

    // Validate vehicle ownership: the selected vehicle's stored userId must match
    // the live auth UID. Firestore cache can serve stale vehicle data from a
    // previous session, causing PERMISSION_DENIED on the vehicle update.
    final vehicleUserId = selectedVehicleData?['userId'] as String?;
    if (vehicleUserId == null || vehicleUserId != authUid) {
      _showSnackBar(
        'Vehicle ownership mismatch — please re-select your vehicle.',
        isError: true,
      );
      setState(() {
        selectedVehicleId = null;
        selectedVehicleData = null;
      });
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isUploading = true;
      _showUploadProgress = true;
    });

    final startTime = DateTime.now();

    try {
      List<String> rcUrls = await _uploadImageList(_documentGroups['rc']!, 'rc');
      List<String> licenseUrls =
      await _uploadImageList(_documentGroups['license']!, 'license');
      List<String> insuranceUrls =
      await _uploadImageList(_documentGroups['insurance']!, 'insurance');
      List<String> pucUrls = await _uploadImageList(_documentGroups['puc']!, 'puc');

      await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .doc(selectedVehicleId)
          .update({
        'documents.rcImages': FieldValue.arrayUnion(rcUrls),
        'documents.licenseImages': FieldValue.arrayUnion(licenseUrls),
        'documents.insuranceImages': FieldValue.arrayUnion(insuranceUrls),
        'documents.pucImages': FieldValue.arrayUnion(pucUrls),
        'documentStatus': 'submitted',
        'documentsUploadedAt': FieldValue.serverTimestamp(),
      });

      final uploadTime = DateTime.now().difference(startTime).inMilliseconds;
      await _logEvent('documents_uploaded', parameters: {
        'vehicle_id': selectedVehicleId,
        'rc_count': rcUrls.length,
        'license_count': licenseUrls.length,
        'insurance_count': insuranceUrls.length,
        'puc_count': pucUrls.length,
        'upload_time_ms': uploadTime,
      });

      // Re-fetch the vehicle from server so the screen immediately shows
      // the submitted documents and "Under Review" banner without requiring
      // the user to re-select the vehicle.
      final vehicleId = selectedVehicleId!;
      DocumentSnapshot<Map<String, dynamic>>? updatedVehicle;
      try {
        updatedVehicle = await FirebaseFirestore.instance
            .collection(TestMode.vehiclesCollection)
            .doc(vehicleId)
            .get(const GetOptions(source: Source.server));
      } catch (_) {
        // Non-fatal — UI will still update via the cleared groups
      }

      if (mounted) {
        setState(() {
          if (updatedVehicle != null && updatedVehicle.exists) {
            selectedVehicleData = updatedVehicle.data();
          } else {
            // Fallback: manually reflect the submitted status in local state
            selectedVehicleData = {
              ...?selectedVehicleData,
              'documentStatus': 'submitted',
            };
          }
          _documentGroups.forEach((key, value) => value.clear());
        });

        _showSnackBar(
          'Documents submitted! Pending admin review.',
          isSuccess: true,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to upload documents: $e', isError: true);
      await _logEvent('document_upload_failed', parameters: {
        'vehicle_id': selectedVehicleId,
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _showUploadProgress = false;
          _uploadProgress.clear();
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final vehicleDetails = selectedVehicleData?['vehicleDetails'] as Map<String, dynamic>?;
    final registrationNumber = vehicleDetails?['registrationNumber'];
    final brand = vehicleDetails?['brand'];
    final model = vehicleDetails?['model'];

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload_file, color: Colors.green, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Upload Documents?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          registrationNumber ?? 'N/A',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (brand != null && model != null)
                          Text(
                            '$brand $model',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'You are about to upload:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (_documentGroups['rc']!.isNotEmpty)
              _buildDocumentCount('RC Book', _documentGroups['rc']!.length),
            if (_documentGroups['license']!.isNotEmpty)
              _buildDocumentCount(
                  'Driving License', _documentGroups['license']!.length),
            if (_documentGroups['insurance']!.isNotEmpty)
              _buildDocumentCount(
                  'Insurance', _documentGroups['insurance']!.length),
            if (_documentGroups['puc']!.isNotEmpty)
              _buildDocumentCount(
                  'PUC Certificate', _documentGroups['puc']!.length),
            const SizedBox(height: 12),
            const Text(
              'Do you want to proceed?',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Upload',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildDocumentCount(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: $count image${count > 1 ? 's' : ''}',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _uploadImageList(List<File> images, String type) async {
    List<String> urls = [];

    for (int i = 0; i < images.length; i++) {
      final compressed = await _compressImage(images[i]);
      if (compressed != null) {
        final fileName = '${type}_${selectedVehicleId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('vehicles')
            .child(widget.userId)
            .child('documents')
            .child(fileName);

        final uploadTask = ref.putFile(compressed);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress[type] =
                  snapshot.bytesTransferred / snapshot.totalBytes;
            });
          }
        });

        await uploadTask;
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
    }

    return urls;
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    scaffoldMessengerKey.currentState
      ?..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: isError
              ? Colors.red
              : (isSuccess ? Colors.green : Colors.grey[800]),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isSuccess ? 2 : 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final documentStatus = selectedVehicleData?['documentStatus'] as String?;
    final canEdit = _canEditDocuments(documentStatus);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard?userId=${widget.userId}'),
        ),
        title: const Text(
          'Document Upload',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 24),
                _buildVehicleSelectionButton(),
                const SizedBox(height: 24),

                if (selectedVehicleId != null) ...[
                  // Approved - View Only
                  if (!canEdit)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Documents Approved',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your documents are verified. View only mode.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _viewDocuments,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('View', style: TextStyle(fontFamily: 'Poppins')),
                          ),
                        ],
                      ),
                    ),

                  // Pending/Rejected with documents - Can manage
                  if (canEdit && _hasExistingDocuments())
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: (documentStatus == 'rejected' ? Colors.red : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: documentStatus == 'rejected' ? Colors.red : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            documentStatus == 'rejected' ? Icons.error_outline : Icons.pending_outlined,
                            color: documentStatus == 'rejected' ? Colors.red : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  documentStatus == 'rejected'
                                      ? 'Documents Rejected'
                                      : 'Documents Under Review',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: documentStatus == 'rejected' ? Colors.red : Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  documentStatus == 'rejected'
                                      ? 'You can view and replace rejected documents.'
                                      : 'You can view and modify documents.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _viewAndEditDocuments,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: documentStatus == 'rejected' ? Colors.red : Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Manage', style: TextStyle(fontFamily: 'Poppins')),
                          ),
                        ],
                      ),
                    ),

                  // Upload sections for canEdit
                  if (canEdit) ...[
                    _buildDocumentSection(
                      'RC Book',
                      'rc',
                      Icons.article,
                      'Upload clear photos of your RC (Registration Certificate)',
                    ),
                    const SizedBox(height: 20),
                    _buildDocumentSection(
                      'Driving License',
                      'license',
                      Icons.credit_card,
                      'Upload front and back of your driving license',
                    ),
                    const SizedBox(height: 20),
                    _buildDocumentSection(
                      'Insurance',
                      'insurance',
                      Icons.shield,
                      'Upload valid vehicle insurance document',
                    ),
                    const SizedBox(height: 20),
                    _buildDocumentSection(
                      'PUC Certificate',
                      'puc',
                      Icons.verified_user,
                      'Upload valid Pollution Under Control certificate',
                    ),
                    const SizedBox(height: 32),
                    _buildUploadButton(),
                  ],
                ] else
                  _buildSelectVehiclePrompt(),

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.greenAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.upload_file,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Documents',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select vehicle and upload documents',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelectionButton() {
    final vehicleDetails = selectedVehicleData?['vehicleDetails'] as Map<String, dynamic>?;
    final registrationNumber = vehicleDetails?['registrationNumber'];
    final brand = vehicleDetails?['brand'];
    final model = vehicleDetails?['model'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _isLoadingVehicles || _isUploading ? null : _showVehicleSelectionSheet,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: selectedVehicleId == null
              ? Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Vehicle',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap to choose a vehicle',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          )
              : Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Selected Vehicle',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'Selected',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      registrationNumber ?? 'N/A',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$brand $model',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isUploading ? null : _showVehicleSelectionSheet,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectVehiclePrompt() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Vehicle Selected',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a vehicle to upload documents',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(
      String title,
      String type,
      IconData icon,
      String description,
      ) {
    final images = _documentGroups[type]!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${images.length} file${images.length != 1 ? 's' : ''} added',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (images.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 12),
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
                            border: Border.all(color: Colors.grey[300]!),
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
              onPressed: _isUploading ? null : () => _pickImage(type),
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(images.isEmpty ? 'Add Photos' : 'Add More'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    final hasDocuments = _documentGroups.values.any((list) => list.isNotEmpty);

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isUploading || !hasDocuments ? null : _uploadDocuments,
        icon: _isUploading
            ? const SizedBox.shrink()
            : const Icon(Icons.cloud_upload, size: 24),
        label: _isUploading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text(
          'Upload Documents',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildUploadProgressOverlay() {
    final vehicleDetails = selectedVehicleData?['vehicleDetails'] as Map<String, dynamic>?;
    final registrationNumber = vehicleDetails?['registrationNumber'];

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_upload,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Uploading Documents...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  registrationNumber ?? 'Vehicle',
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Do not close this screen',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
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
