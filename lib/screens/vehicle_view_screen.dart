import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/test_mode.dart';

class VehicleViewScreen extends StatefulWidget {
  final String userId;
  final String vehicleId;

  const VehicleViewScreen({
    super.key,
    required this.userId,
    required this.vehicleId,
  });

  @override
  State<VehicleViewScreen> createState() => _VehicleViewScreenState();
}

class _VehicleViewScreenState extends State<VehicleViewScreen> {
  final _analytics = FirebaseAnalytics.instance;
  bool isLoading = true;
  Map<String, dynamic>? vehicleData;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
    _logScreenView();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'VehicleView',
      screenClass: 'VehicleViewScreen',
    );
  }

  Future<void> _loadVehicleData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .doc(widget.vehicleId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          vehicleData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        if (mounted) {
          _showSnackBar('Vehicle not found', isError: true);
          context.go('/vehicle-list?userId=${widget.userId}'); // UPDATED: Go to vehicle list
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        _showSnackBar('Failed to load vehicle: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vehicle-list?userId=${widget.userId}'), // UPDATED: Go to vehicle list
        ),
        title: const Text(
          'Vehicle Details',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (vehicleData != null &&
              vehicleData!['documentStatus'] != 'approved')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.go(
                  '/vehicle-edit?userId=${widget.userId}&vehicleId=${widget.vehicleId}',
                );
              },
              tooltip: 'Edit Vehicle',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : vehicleData == null
          ? const Center(child: Text('No data available'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(),
            const SizedBox(height: 24),
            _buildVehicleImagesSection(),
            const SizedBox(height: 24),
            _buildVehicleDetailsCard(),
            const SizedBox(height: 24),
            _buildDocumentsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = vehicleData!['documentStatus'] ?? 'pending';
    final color = _getStatusBgColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            status == 'approved'
                ? Icons.check_circle
                : status == 'rejected'
                ? Icons.cancel
                : Icons.pending,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  status == 'approved'
                      ? 'Your vehicle has been approved'
                      : status == 'rejected'
                      ? 'Your vehicle registration was rejected'
                      : 'Your vehicle is under review',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleImagesSection() {
    final documents = vehicleData!['documents'] as Map<String, dynamic>?;
    final vehicleImages =
    List<String>.from(documents?['vehicleImages'] ?? []);

    if (vehicleImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Photos',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: vehicleImages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showImageDialog(vehicleImages[index]),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: vehicleImages[index],
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleDetailsCard() {
    final details = vehicleData!['vehicleDetails'] as Map<String, dynamic>?;

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
                  'Vehicle Information',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Category', details?['category'] ?? 'N/A'),
            _buildDetailRow('Brand', details?['brand'] ?? 'N/A'),
            _buildDetailRow('Model', details?['model'] ?? 'N/A'),
            _buildDetailRow('Color', details?['color'] ?? 'N/A'),
            _buildDetailRow('Year', details?['year']?.toString() ?? 'N/A'),
            _buildDetailRow('Registration Number',
                details?['registrationNumber'] ?? 'N/A'),
            _buildDetailRow('Seating Capacity',
                details?['seatingCapacity']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final documents = vehicleData!['documents'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_open, color: Colors.blue[700], size: 24),
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
        const SizedBox(height: 16),
        _buildDocumentCard(
          'RC Certificate',
          Icons.description,
          List<String>.from(documents?['rcImages'] ?? []),
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          'Driving License',
          Icons.credit_card,
          List<String>.from(documents?['licenseImages'] ?? []),
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          'Insurance',
          Icons.security,
          List<String>.from(documents?['insuranceImages'] ?? []),
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          'PUC Certificate',
          Icons.verified,
          List<String>.from(documents?['pucImages'] ?? []),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(String title, IconData icon, List<String> images) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[700]),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${images.length} file(s)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: images.isEmpty
            ? const Icon(Icons.remove_circle_outline, color: Colors.grey)
            : const Icon(Icons.check_circle, color: Colors.green),
        onTap: images.isEmpty
            ? null
            : () => _showDocumentImagesDialog(title, images),
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentImagesDialog(String title, List<String> images) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showImageDialog(images[index]);
                      },
                      child: Container(
                        height: 120,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: images[index],
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}