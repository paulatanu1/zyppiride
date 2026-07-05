import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../core/constants/test_mode.dart';
import '../core/utils/app_logger.dart';
import '../main.dart' show scaffoldMessengerKey;

class AgreementSigningScreen extends StatefulWidget {
  final String userId;
  final String? vehicleId;

  const AgreementSigningScreen({
    super.key,
    required this.userId,
    this.vehicleId,
  });

  @override
  State<AgreementSigningScreen> createState() => _AgreementSigningScreenState();
}

class _AgreementSigningScreenState extends State<AgreementSigningScreen> {
  final _analytics = FirebaseAnalytics.instance;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  bool _hasSignature = false;
  String? _selectedVehicleId;
  Map<String, dynamic>? _vehicleData;
  bool? _hasAgreement;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
    _scrollController.addListener(_onScroll);
    _logScreenView();

    if (_selectedVehicleId != null) {
      _fetchVehicleData();
      _checkAgreement();
    }
  }

  Future<void> _fetchVehicleData() async {
    try {
      final vehicleDoc = await FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .doc(_selectedVehicleId)
          .get();
      if (mounted && vehicleDoc.exists) {
        setState(() {
          _vehicleData = vehicleDoc.data();
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching vehicle data', tag: 'Agreement', error: e);
    }
  }

  Future<void> _checkAgreement() async {
    try {
      final agreementDoc = await FirebaseFirestore.instance
          .collection(TestMode.agreementsCollection)
          .doc('${widget.userId}_$_selectedVehicleId')
          .get();
      if (mounted) {
        setState(() {
          _hasAgreement = agreementDoc.exists;
        });
      }
    } catch (e) {
      AppLogger.error('Error checking agreement', tag: 'Agreement', error: e);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    }
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'AgreementSigning',
      screenClass: 'AgreementSigningScreen',
    );
  }

  Future<void> _submitAgreement(
      Map<String, dynamic> vehicleData, String vehicleId, Uint8List signatureBytes) async {
    if (!_hasScrolledToBottom) {
      _showSnackBar('Please read the entire agreement', Colors.orange);
      return;
    }

    if (!_agreedToTerms) {
      _showSnackBar('Please agree to the terms and conditions', Colors.orange);
      return;
    }

    if (!_hasSignature) {
      _showSnackBar('Please provide a signature', Colors.orange);
      return;
    }

    // Guard: Firestore rules check request.auth.uid against userId fields
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null || authUid != widget.userId) {
      _showSnackBar('Session error — please log out and log in again.', Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final agreementRef = FirebaseFirestore.instance
          .collection(TestMode.agreementsCollection)
          .doc('${widget.userId}_$vehicleId');

      // Bypass local cache — if a previous attempt already wrote the document,
      // a cached read would return "not found" and the subsequent set() would be
      // evaluated as an UPDATE by Firestore rules (allow update = false → denied).
      final existingAgreement =
          await agreementRef.get(const GetOptions(source: Source.server));
      if (existingAgreement.exists) {
        if (mounted) setState(() { _hasAgreement = true; _isSubmitting = false; });
        _showSnackBar('Agreement already signed!', Colors.green);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection(TestMode.usersCollection)
          .doc(widget.userId)
          .get();
      final userData = userDoc.data() ?? {};
      final ownerName = userData['name'] ?? 'N/A';

      final vehicleDetails =
          vehicleData['vehicleDetails'] as Map<String, dynamic>? ?? {};
      final signatureBase64 = base64Encode(signatureBytes);

      // Create the agreement document (rules: allow create if isOwner() && isValidAgreement())
      await agreementRef.set({
        'userId': widget.userId,
        'vehicleId': vehicleId,
        'ownerName': ownerName,
        'vehicleRegistrationNumber':
            vehicleDetails['registrationNumber'] ?? 'N/A',
        'vehicleBrand': vehicleDetails['brand'] ?? '',
        'vehicleModel': vehicleDetails['model'] ?? '',
        'vehicleCategory': vehicleDetails['category'] ?? 'private',
        'signatureData': signatureBase64,
        'agreedToTerms': true,
        'signedAt': FieldValue.serverTimestamp(),
        'ipAddress': 'N/A',
        'deviceInfo': 'Flutter App',
      });

      await _analytics.logEvent(
        name: 'agreement_signed',
        parameters: {
          'user_id': widget.userId,
          'vehicle_id': vehicleId,
        },
      );

      if (!mounted) return;
      _showSnackBar('Agreement signed successfully!', Colors.green);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      context.go('/dashboard?userId=${widget.userId}');
    } catch (e) {
      AppLogger.error('Error submitting agreement', tag: 'Agreement', error: e);
      _showSnackBar('Failed to submit agreement: ${e.runtimeType}', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    scaffoldMessengerKey.currentState
      ?..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard?userId=${widget.userId}'),
        ),
        title: const Text(
          'Agreement Signing',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _selectedVehicleId == null
          ? _buildVehicleSelector()
          : _buildAgreementContent(),
    );
  }

  Widget _buildVehicleSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(TestMode.vehiclesCollection)
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No vehicles registered',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        final vehicles = snapshot.data!.docs;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[700]!, Colors.purple[500]!],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Vehicle',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose a vehicle to sign the agreement',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final doc = vehicles[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final vehicleDetails =
                      data['vehicleDetails'] as Map<String, dynamic>? ?? {};

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection(TestMode.agreementsCollection)
                        .doc('${widget.userId}_${doc.id}')
                        .get(),
                    builder: (context, agreementSnap) {
                      final hasAgreement =
                          agreementSnap.hasData && agreementSnap.data!.exists;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: hasAgreement
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hasAgreement
                                  ? Icons.check_circle
                                  : Icons.directions_car,
                              color: hasAgreement
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                          title: Text(
                            vehicleDetails['registrationNumber'] ?? 'N/A',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${vehicleDetails['brand'] ?? ''} ${vehicleDetails['model'] ?? ''}'
                                .trim(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: hasAgreement
                              ? const Chip(
                            label: Text(
                              'Signed',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.green,
                          )
                              : const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            setState(() {
                              _selectedVehicleId = doc.id;
                              _vehicleData = null;
                              _hasAgreement = null;
                              _hasScrolledToBottom = false;
                              _agreedToTerms = false;
                              _hasSignature = false;
                            });
                            _fetchVehicleData();
                            _checkAgreement();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignedAgreementView(Map<String, dynamic> agreementData) {
    final ownerName = agreementData['ownerName'] ?? 'N/A';
    final vehicleRegistrationNumber =
        agreementData['vehicleRegistrationNumber'] ?? 'N/A';
    final vehicleCategory = agreementData['vehicleCategory'] ?? 'private';
    final vehicleBrand = agreementData['vehicleBrand'] ?? '';
    final vehicleModel = agreementData['vehicleModel'] ?? '';
    final signedAt = agreementData['signedAt'] as Timestamp?;
    final signatureBase64 = agreementData['signatureData'] as String?;

    Uint8List? signatureData;
    if (signatureBase64 != null) {
      try {
        signatureData = base64Decode(signatureBase64);
      } catch (e) {
        AppLogger.error('Error decoding signature', tag: 'Agreement', error: e);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[700]!, Colors.green[500]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Agreement Signed',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  signedAt != null
                      ? 'Signed on ${_formatDateTime(signedAt)}'
                      : 'Signed',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            'Vehicle Owner Information',
            [
              _buildInfoRow('Owner Name', ownerName, bold: true),
              _buildInfoRow('Vehicle Number', vehicleRegistrationNumber),
              _buildInfoRow('Vehicle Type',
                  vehicleCategory.toUpperCase(), bold: true),
              if (vehicleBrand.isNotEmpty || vehicleModel.isNotEmpty)
                _buildInfoRow('Model', '$vehicleBrand $vehicleModel'.trim()),
            ],
          ),
          const SizedBox(height: 16),
          if (signatureData != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Digital Signature',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        signatureData,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This agreement is legally binding. Keep a copy for your records. Contact support for any queries.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                context.go('/dashboard?userId=${widget.userId}');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple[700],
                side: BorderSide(color: Colors.purple[700]!, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home),
                  SizedBox(width: 8),
                  Text(
                    'Back to Dashboard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementContent() {
    if (_vehicleData == null || _hasAgreement == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasAgreement!) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection(TestMode.agreementsCollection)
            .doc('${widget.userId}_$_selectedVehicleId')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildSignedAgreementView(
              snapshot.data!.data() as Map<String, dynamic>);
        },
      );
    } else {
      return _buildSigningView(_vehicleData!, _selectedVehicleId!);
    }
  }

  Widget _buildSigningView(Map<String, dynamic> vehicleData, String vehicleId) {
    final vehicleDetails =
        vehicleData['vehicleDetails'] as Map<String, dynamic>? ?? {};
    final registrationNumber = vehicleDetails['registrationNumber'] ?? 'N/A';
    final category = vehicleDetails['category'] ?? 'private';
    final brand = vehicleDetails['brand'] ?? '';
    final model = vehicleDetails['model'] ?? '';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('agreement_scroll_view'),
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAgreementHeader(
                    'N/A', registrationNumber, category, brand, model),
                const SizedBox(height: 24),
                _buildAgreementText(category),
                const SizedBox(height: 32),
                SignatureSection(
                  onSignatureChanged: (hasSignature) {
                    setState(() {
                      _hasSignature = hasSignature;
                    });
                  },
                ),
                const SizedBox(height: 24),
                _buildCheckboxSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        _buildSubmitButton(vehicleData, vehicleId),
      ],
    );
  }

  Widget _buildAgreementHeader(String ownerName, String registrationNumber,
      String category, String brand, String model) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[700]!, Colors.purple[500]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ZYPPI RIDE',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vehicle Owner Agreement',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const Divider(color: Colors.white70, height: 32),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white,
              ),
              children: [
                const TextSpan(text: 'Owner Name: '),
                TextSpan(
                  text: ownerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white,
              ),
              children: [
                const TextSpan(text: 'Vehicle: '),
                TextSpan(
                  text: registrationNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white,
              ),
              children: [
                const TextSpan(text: 'Vehicle Type: '),
                TextSpan(
                  text: category.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (brand.isNotEmpty || model.isNotEmpty) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
                children: [
                  const TextSpan(text: 'Model: '),
                  TextSpan(
                    text: '$brand $model'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgreementText(String category) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TERMS AND CONDITIONS',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This Vehicle Owner Agreement ("Agreement") is entered into between the vehicle owner (hereinafter referred to as "Owner") and Zyppi Ride (hereinafter referred to as "Company").',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            '1. Vehicle Registration',
            'The Owner agrees to register their vehicle with Zyppi Ride for ${category == "commercial" ? "commercial ride-sharing" : "private ride-sharing"} purposes. The vehicle must meet all legal requirements including valid registration, insurance, and fitness certificates.',
          ),
          _buildSection(
            '2. Owner Responsibilities',
            '• Maintain the vehicle in good working condition\n'
                '• Ensure all documents are valid and up-to-date\n'
                '• Comply with all traffic rules and regulations\n'
                '• Maintain comprehensive insurance coverage\n'
                '• Report any accidents or damages immediately\n'
                '• Ensure the vehicle passes regular safety inspections',
          ),
          _buildSection(
            '3. Company Rights',
            'Zyppi Ride reserves the right to:\n'
                '• Verify vehicle documents at any time\n'
                '• Suspend or terminate vehicle registration if requirements are not met\n'
                '• Set commission rates and payment terms\n'
                '• Update terms and conditions with prior notice',
          ),
          _buildSection(
            '4. Revenue Sharing',
            category == 'commercial'
                ? 'For commercial vehicles, the revenue sharing model will be as per the agreed commission structure. The Company will deduct its commission before remitting payments to the Owner.'
                : 'For private vehicles, earnings will be calculated based on completed trips. The Company will deduct its service fee as per the agreed terms.',
          ),
          _buildSection(
            '5. Insurance and Liability',
            'The Owner must maintain comprehensive insurance coverage including third-party liability. The Owner is responsible for any damages, accidents, or legal issues arising from vehicle operation. Zyppi Ride is not liable for any incidents during vehicle operation.',
          ),
          _buildSection(
            '6. Data Privacy',
            'The Owner consents to Zyppi Ride collecting and processing vehicle and trip data for service improvement, safety, and regulatory compliance. Personal information will be handled as per our Privacy Policy.',
          ),
          _buildSection(
            '7. Termination',
            'Either party may terminate this agreement with 30 days written notice. Upon termination, all pending payments will be settled within 15 business days. The Owner must remove all Zyppi Ride branding from the vehicle.',
          ),
          _buildSection(
            '8. Dispute Resolution',
            'Any disputes arising from this agreement will be resolved through mutual discussion. If unresolved, disputes will be subject to arbitration under the applicable laws of the jurisdiction.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please read all terms carefully before signing. By signing, you acknowledge that you have read, understood, and agree to all terms and conditions.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: _hasScrolledToBottom
                  ? (value) {
                setState(() {
                  _agreedToTerms = value ?? false;
                });
              }
                  : null,
              activeColor: Colors.purple[700],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: _hasScrolledToBottom
                        ? Colors.black87
                        : Colors.grey[400],
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'I hereby confirm that I have read and ',
                    ),
                    TextSpan(
                      text: 'agree to all terms and conditions ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _hasScrolledToBottom
                            ? Colors.purple[700]
                            : Colors.grey[400],
                      ),
                    ),
                    const TextSpan(
                      text:
                      'stated in this agreement. I understand my responsibilities as a vehicle owner on the Zyppi Ride platform.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Map<String, dynamic> vehicleData, String vehicleId) {
    final canSubmit = _hasScrolledToBottom && _agreedToTerms && _hasSignature;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasScrolledToBottom)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please scroll to the bottom to read all terms',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canSubmit && !_isSubmitting
                  ? () async {
                if (SignatureSection.signatureController?.isEmpty ?? true) {
                  _showSnackBar('Please provide a signature', Colors.red);
                  return;
                }
                final signatureBytes =
                await SignatureSection.signatureController?.toPngBytes();
                if (signatureBytes != null) {
                  unawaited(_submitAgreement(vehicleData, vehicleId, signatureBytes));
                } else {
                  _showSnackBar('Failed to capture signature', Colors.red);
                }
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit ? Colors.purple[700] : Colors.grey[300],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: canSubmit ? 4 : 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Sign & Submit Agreement',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignatureSection extends StatefulWidget {
  final Function(bool) onSignatureChanged;

  const SignatureSection({super.key, required this.onSignatureChanged});

  static SignatureController? signatureController;

  @override
  State<SignatureSection> createState() => _SignatureSectionState();
}

class _SignatureSectionState extends State<SignatureSection> {
  late final SignatureController _signatureController;
  bool _hasSignature = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    SignatureSection.signatureController = _signatureController;

    _signatureController.addListener(() {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer!.cancel();
      }
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        final hasSignature = _signatureController.isNotEmpty;
        if (hasSignature != _hasSignature) {
          setState(() {
            _hasSignature = hasSignature;
          });
          widget.onSignatureChanged(hasSignature);
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _signatureController.dispose();
    SignatureSection.signatureController = null;
    super.dispose();
  }

  void _clearSignature() {
    _signatureController.clear();
    setState(() {
      _hasSignature = false;
    });
    widget.onSignatureChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Digital Signature',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_hasSignature)
                TextButton(
                  onPressed: _clearSignature,
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 18, color: Colors.purple),
                      SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.grey[50]!,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.edit, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sign above with your finger or stylus',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}