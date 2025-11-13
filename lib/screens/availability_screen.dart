// lib/screens/availability_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================
// MODELS
// ============================================

class VehicleModel {
  final String vehicleId;
  final Map<String, dynamic> vehicleDetails;
  final bool isActive;
  final String availabilityMode;
  final int documentCount;
  final int blockedDatesCount;
  final String documentStatus;

  VehicleModel({
    required this.vehicleId,
    required this.vehicleDetails,
    required this.isActive,
    required this.availabilityMode,
    required this.documentCount,
    required this.blockedDatesCount,
    required this.documentStatus,
  });

  factory VehicleModel.fromFirestore(
      String id,
      Map<String, dynamic> data,
      int docCount,
      int blockedCount,
      ) {
    final docStatus = data['documentStatus'];
    final String status = (docStatus is String && docStatus.isNotEmpty)
        ? docStatus
        : 'pending';

    return VehicleModel(
      vehicleId: id,
      vehicleDetails: data['vehicleDetails'] is Map<String, dynamic>
          ? data['vehicleDetails']
          : {},
      isActive: data['isActive'] == true,
      availabilityMode: (data['availabilityMode'] is String && (data['availabilityMode'] as String).isNotEmpty)
          ? data['availabilityMode']
          : 'full_time',
      documentCount: docCount,
      blockedDatesCount: blockedCount,
      documentStatus: status,
    );
  }

  String get vehicleName {
    final brand = vehicleDetails['brand'] ?? '';
    final model = vehicleDetails['model'] ?? '';
    if (brand.isEmpty && model.isEmpty) return 'Unknown Vehicle';
    return '$brand $model'.trim();
  }

  String get registrationNumber =>
      vehicleDetails['registrationNumber'] ?? 'N/A';

  String get vehicleType => vehicleDetails['category'] ?? 'N/A';

  String? get imageUrl {
    final images = vehicleDetails['images'];
    if (images == null) return null;
    if (images is List && images.isNotEmpty) {
      return images[0];
    }
    if (images is String && images.isNotEmpty) {
      return images;
    }
    return null;
  }

  bool get isApproved => documentStatus.toLowerCase() == 'approved';

  bool get canAcceptBookings => isApproved && isActive;
}

class BookingModel {
  final String bookingId;
  final String vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String customerName;

  BookingModel({
    required this.bookingId,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.customerName,
  });

  factory BookingModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BookingModel(
      bookingId: id,
      vehicleId: data['vehicleId'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      customerName: data['customerName'] ?? 'Unknown',
    );
  }
}

// ============================================
// AVAILABILITY SCREEN
// ============================================

class AvailabilityScreen extends StatefulWidget {
  final String userId;

  const AvailabilityScreen({super.key, required this.userId});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  String? selectedVehicleId;
  List<VehicleModel> allVehicles = [];
  VehicleModel? vehicleData;
  List<BookingModel> upcomingBookings = [];
  bool isLoading = true;
  bool isLoadingBookings = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserVehicles();
  }

  Future<void> _loadUserVehicles() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('userId', isEqualTo: widget.userId)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No vehicles found';
        });
        return;
      }

      List<VehicleModel> vehicles = [];
      for (var doc in snapshot.docs) {
        final docsSnapshot = await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(doc.id)
            .collection('documents')
            .where('status', isEqualTo: 'approved')
            .get();

        final blockedSnapshot = await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(doc.id)
            .collection('blocked_dates')
            .get();

        vehicles.add(VehicleModel.fromFirestore(
          doc.id,
          doc.data(),
          docsSnapshot.docs.length,
          blockedSnapshot.docs.length,
        ));
      }

      if (mounted) {
        setState(() {
          allVehicles = vehicles;
          selectedVehicleId = vehicles.first.vehicleId;
          vehicleData = vehicles.first;
          isLoading = false;
        });
        await _loadUpcomingBookings();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading vehicles: $e';
        });
      }
    }
  }

  Future<void> _onVehicleChanged(String? newVehicleId) async {
    if (newVehicleId == null || newVehicleId == selectedVehicleId) return;

    setState(() {
      selectedVehicleId = newVehicleId;
      vehicleData = allVehicles.firstWhere((v) => v.vehicleId == newVehicleId);
      isLoadingBookings = true;
    });

    await _loadUpcomingBookings();
  }

  Future<void> _loadUpcomingBookings() async {
    if (selectedVehicleId == null) return;

    setState(() {
      isLoadingBookings = true;
    });

    try {
      final now = DateTime.now();
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('vehicleId', isEqualTo: selectedVehicleId)
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('startDate')
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          upcomingBookings = bookingsSnapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc.data(), doc.id))
              .toList();
          isLoadingBookings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          upcomingBookings = [];
          isLoadingBookings = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadUserVehicles();
  }

  Future<void> _toggleActive(bool value) async {
    if (selectedVehicleId == null || vehicleData == null) return;

    if (value && !vehicleData!.isApproved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Cannot activate vehicle. Document verification is pending or rejected.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View Details',
              textColor: Colors.white,
              onPressed: () {
                _showDocumentStatusDialog();
              },
            ),
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(selectedVehicleId)
          .update({'isActive': value});

      if (mounted) {
        setState(() {
          vehicleData = VehicleModel(
            vehicleId: vehicleData!.vehicleId,
            vehicleDetails: vehicleData!.vehicleDetails,
            isActive: value,
            availabilityMode: vehicleData!.availabilityMode,
            documentCount: vehicleData!.documentCount,
            blockedDatesCount: vehicleData!.blockedDatesCount,
            documentStatus: vehicleData!.documentStatus,
          );

          final index = allVehicles.indexWhere((v) => v.vehicleId == selectedVehicleId);
          if (index != -1) {
            allVehicles[index] = vehicleData!;
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Vehicle activated - Ready to accept bookings' : 'Vehicle deactivated',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAvailabilityMode(String mode) async {
    if (selectedVehicleId == null || vehicleData == null) return;

    if (!vehicleData!.isApproved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Cannot update availability. Document verification required.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(selectedVehicleId)
          .update({'availabilityMode': mode});

      setState(() {
        vehicleData = VehicleModel(
          vehicleId: vehicleData!.vehicleId,
          vehicleDetails: vehicleData!.vehicleDetails,
          isActive: vehicleData!.isActive,
          availabilityMode: mode,
          documentCount: vehicleData!.documentCount,
          blockedDatesCount: vehicleData!.blockedDatesCount,
          documentStatus: vehicleData!.documentStatus,
        );

        final index = allVehicles.indexWhere((v) => v.vehicleId == selectedVehicleId);
        if (index != -1) {
          allVehicles[index] = vehicleData!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Availability mode updated',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // FIXED: Use pop() with fallback to go()
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard?userId=${widget.userId}');
            }
          },
        ),
        title: const Text(
          'Availability Dashboard',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildErrorState()
          : vehicleData == null
          ? _buildNoVehicleState()
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVehicleDropdown(),
              const SizedBox(height: 16),
              if (vehicleData != null && !vehicleData!.isApproved)
                _buildDocumentStatusWarning(vehicleData!),
              if (vehicleData != null && !vehicleData!.isApproved)
                const SizedBox(height: 16),
              _buildVehicleCard(vehicleData!),
              const SizedBox(height: 24),
              _buildQuickStats(vehicleData!),
              const SizedBox(height: 24),
              _buildActiveToggle(vehicleData!),
              const SizedBox(height: 24),
              _buildAvailabilityMode(vehicleData!),
              const SizedBox(height: 24),
              _buildActionGrid(),
              const SizedBox(height: 24),
              _buildUpcomingBookings(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentStatusWarning(VehicleModel vehicle) {
    final statusColor = vehicle.documentStatus.toLowerCase() == 'pending'
        ? Colors.orange
        : Colors.red;
    final statusIcon = vehicle.documentStatus.toLowerCase() == 'pending'
        ? Icons.pending_outlined
        : Icons.cancel_outlined;
    final statusMessage = vehicle.documentStatus.toLowerCase() == 'pending'
        ? 'Document verification pending'
        : 'Document verification ${vehicle.documentStatus}';

    return Card(
      elevation: 2,
      color: statusColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vehicle cannot accept bookings until documents are approved',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              color: statusColor,
              onPressed: _showDocumentStatusDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentStatusDialog() {
    if (vehicleData == null) return;

    final status = vehicleData!.documentStatus.toLowerCase();
    String title = 'Document Status';
    String message = '';
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;

    switch (status) {
      case 'approved':
        title = 'Documents Approved ✓';
        message = 'Your vehicle documents have been verified and approved. You can now accept bookings.';
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'pending':
        title = 'Verification Pending';
        message = 'Your vehicle documents are under review. This process typically takes 24-48 hours. You will be notified once approved.';
        icon = Icons.pending_outlined;
        color = Colors.orange;
        break;
      case 'rejected':
        title = 'Documents Rejected';
        message = 'Your vehicle documents were rejected. Please review and resubmit the required documents with correct information.';
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        message = 'Document status: ${vehicleData!.documentStatus}. Please contact support for more information.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Documents: ${vehicleData!.documentCount}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          if (status != 'approved')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // FIXED: Use pushNamed instead of go
                context.pushNamed(
                  'document-upload',
                  queryParameters: {
                    'userId': widget.userId,
                    'vehicleId': selectedVehicleId ?? '',
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Manage Documents',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedVehicleId,
                  isExpanded: true,
                  hint: const Text(
                    'Select a vehicle',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                  items: allVehicles.map((vehicle) {
                    return DropdownMenuItem<String>(
                      value: vehicle.vehicleId,
                      child: Text(
                        '${vehicle.vehicleName} (${vehicle.registrationNumber})',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onVehicleChanged,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error: $errorMessage',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserVehicles,
            child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVehicleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No vehicles found',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // FIXED: Use pushNamed instead of go
              context.pushNamed(
                'vehicle-registration',
                queryParameters: {'userId': widget.userId},
              );
            },
            child: const Text('Add Vehicle', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: vehicle.imageUrl != null
                    ? Image.network(
                  vehicle.imageUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.directions_car,
                      size: 48,
                      color: Colors.blue.shade700,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    );
                  },
                )
                    : Icon(
                  Icons.directions_car,
                  size: 48,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.vehicleName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle.registrationNumber,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${vehicle.vehicleType}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: vehicle.isActive ? Colors.green.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      vehicle.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: vehicle.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(VehicleModel vehicle) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Documents',
            '${vehicle.documentCount}',
            Icons.description,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Blocked Days',
            '${vehicle.blockedDatesCount}',
            Icons.block,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveToggle(VehicleModel vehicle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Status',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enable to accept bookings',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Switch(
              value: vehicle.isActive,
              onChanged: _toggleActive,
              activeThumbColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityMode(VehicleModel vehicle) {
    final isEnabled = vehicle.isApproved;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Availability Mode',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isEnabled)
                  Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: Column(
                children: [
                  _buildCustomRadioOption(
                    'Full Time',
                    'Available 24/7',
                    'full_time',
                    vehicle.availabilityMode,
                    isEnabled,
                  ),
                  _buildCustomRadioOption(
                    'Part Time',
                    'Custom schedule',
                    'part_time',
                    vehicle.availabilityMode,
                    isEnabled,
                  ),
                  _buildCustomRadioOption(
                    'On Demand',
                    'Manual approval',
                    'on_demand',
                    vehicle.availabilityMode,
                    isEnabled,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRadioOption(
      String title,
      String subtitle,
      String value,
      String currentValue,
      bool isEnabled,
      ) {
    final bool isSelected = value == currentValue;

    return InkWell(
      onTap: isEnabled ? () => _updateAvailabilityMode(value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isEnabled
                      ? (isSelected ? Colors.blue : Colors.grey)
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? Colors.blue : Colors.grey.shade300,
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isEnabled
                          ? (isSelected ? Colors.blue : Colors.black87)
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: isEnabled ? Colors.grey : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      {
        'title': 'Manage Schedule',
        'icon': Icons.calendar_today,
        'color': Colors.blue,
        'routeName': 'manage-schedule',
      },
      {
        'title': 'Blocked Dates',
        'icon': Icons.block,
        'color': Colors.orange,
        'routeName': 'blocked-dates',
      },
      {
        'title': 'Pricing Rules',
        'icon': Icons.attach_money,
        'color': Colors.green,
        'routeName': 'pricing-rules',
      },
      {
        'title': 'Booking Settings',
        'icon': Icons.settings,
        'color': Colors.purple,
        'routeName': 'booking-settings',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  // FIXED: Use pushNamed instead of go
                  context.pushNamed(
                    action['routeName'] as String,
                    queryParameters: {
                      'userId': widget.userId,
                      'vehicleId': selectedVehicleId ?? '',
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        size: 40,
                        color: action['color'] as Color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['title'] as String,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Bookings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        isLoadingBookings
            ? const Center(child: CircularProgressIndicator())
            : upcomingBookings.isEmpty
            ? Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'No upcoming bookings',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: upcomingBookings.length,
          itemBuilder: (context, index) {
            final booking = upcomingBookings[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.person, color: Colors.blue.shade700),
                ),
                title: Text(
                  booking.customerName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${_formatDate(booking.startDate)} - ${_formatDate(booking.endDate)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
