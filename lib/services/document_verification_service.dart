import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';

/// Service for document verification workflow
class DocumentVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get verification status for a user
  Future<Result<VerificationStatus>> getVerificationStatus(String userId) async {
    try {
      AppLogger.firestore('GET', 'users', docId: '$userId (verification)');

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return Result.failure(DatabaseException.notFound('User'));
      }

      final data = userDoc.data()!;
      final status = VerificationStatus.fromMap(data);

      return Result.success(status);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getVerificationStatus');
      return Result.failure(exception);
    }
  }

  /// Check all vehicles for document status
  Future<Result<List<VehicleVerificationInfo>>> getVehicleVerificationStatus(
    String userId,
  ) async {
    try {
      AppLogger.firestore('QUERY', 'vehicles', docId: 'user: $userId');

      final vehiclesSnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .get();

      final vehicles = vehiclesSnapshot.docs.map((doc) {
        final data = doc.data();
        final rawStatus = data['documentStatus'] as String? ?? 'pending';
        return VehicleVerificationInfo(
          vehicleId: doc.id,
          registrationNumber:
              data['vehicleDetails']?['registrationNumber'] ?? '',
          documentStatus: rawStatus.toLowerCase(),
          hasAllDocuments: _hasAllRequiredDocuments(data['documents']),
        );
      }).toList();

      AppLogger.success(
        'Found ${vehicles.length} vehicles for verification check',
        tag: 'DocumentVerificationService',
      );

      return Result.success(vehicles);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getVehicleVerificationStatus');
      return Result.failure(exception);
    }
  }

  bool _hasAllRequiredDocuments(Map<String, dynamic>? documents) {
    if (documents == null) return false;

    final rcImages = documents['rcImages'] as List?;
    final licenseImages = documents['licenseImages'] as List?;
    final insuranceImages = documents['insuranceImages'] as List?;
    final pucImages = documents['pucImages'] as List?;

    return (rcImages?.isNotEmpty == true) &&
        (licenseImages?.isNotEmpty == true) &&
        (insuranceImages?.isNotEmpty == true) &&
        (pucImages?.isNotEmpty == true);
  }

  /// Submit documents for verification
  Future<Result<void>> submitForVerification(String userId) async {
    try {
      AppLogger.info(
        'Submitting documents for verification',
        tag: 'DocumentVerificationService',
      );

      final batch = _firestore.batch();

      // Update user verification status
      batch.update(_firestore.collection('users').doc(userId), {
        'verificationStatus': 'submitted',
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      });

      // Update all vehicles to submitted
      final vehiclesSnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in vehiclesSnapshot.docs) {
        batch.update(doc.reference, {
          'documentStatus': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      AppLogger.success(
        'Documents submitted for verification',
        tag: 'DocumentVerificationService',
      );

      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'submitForVerification');
      return Result.failure(exception);
    }
  }

  /// Check if user can go online (all docs approved)
  Future<Result<OnlineEligibility>> checkOnlineEligibility(String userId) async {
    try {
      AppLogger.firestore('GET', 'users', docId: '$userId (eligibility)');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData == null) {
        return Result.failure(DatabaseException.notFound('User'));
      }

      // Check vehicles
      final vehiclesSnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .get();

      if (vehiclesSnapshot.docs.isEmpty) {
        return Result.success(OnlineEligibility(
          canGoOnline: false,
          reason: 'No vehicles registered',
          missingItems: ['vehicle_registration'],
        ));
      }

      final List<String> missingItems = [];

      // Check each vehicle
      bool hasApprovedVehicle = false;
      for (final doc in vehiclesSnapshot.docs) {
        final data = doc.data();
        final docStatus = (data['documentStatus'] as String?)?.toLowerCase();

        if (docStatus == 'approved') {
          hasApprovedVehicle = true;
        } else {
          missingItems.add('vehicle_documents');
        }
      }

      // Can go online if at least one vehicle document is approved
      // User verification status is optional - vehicle approval is sufficient
      final canGoOnline = hasApprovedVehicle;

      String? reason;
      if (!canGoOnline) {
        // Check if any vehicle has documents submitted for review
        bool hasSubmittedVehicle = false;
        for (final doc in vehiclesSnapshot.docs) {
          final data = doc.data();
          final docStatus = (data['documentStatus'] as String?)?.toLowerCase();
          if (docStatus == 'submitted') {
            hasSubmittedVehicle = true;
            break;
          }
        }

        if (hasSubmittedVehicle) {
          reason = 'Vehicle documents under review';
        } else {
          reason = 'Please upload and submit vehicle documents';
        }
      }

      AppLogger.debug(
        'Online eligibility: $canGoOnline, reason: $reason',
        tag: 'DocumentVerificationService',
      );

      return Result.success(OnlineEligibility(
        canGoOnline: canGoOnline,
        reason: reason,
        missingItems: missingItems,
      ));
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'checkOnlineEligibility');
      return Result.failure(exception);
    }
  }

  /// Stream verification status
  Stream<VerificationStatus> watchVerificationStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => VerificationStatus.fromMap(snapshot.data() ?? {}));
  }

  /// Stream online eligibility - auto-updates when vehicle status changes
  Stream<OnlineEligibility> watchOnlineEligibility(String userId) {
    return _firestore
        .collection('vehicles')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return OnlineEligibility(
          canGoOnline: false,
          reason: 'No vehicles registered',
          missingItems: ['vehicle_registration'],
        );
      }

      bool hasApprovedVehicle = false;
      bool hasSubmittedVehicle = false;
      final List<String> missingItems = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docStatus = (data['documentStatus'] as String?)?.toLowerCase();

        AppLogger.debug(
          'Vehicle ${doc.id} documentStatus: $docStatus',
          tag: 'DocumentVerificationService',
        );

        if (docStatus == 'approved') {
          hasApprovedVehicle = true;
        } else if (docStatus == 'submitted') {
          hasSubmittedVehicle = true;
          missingItems.add('vehicle_documents');
        } else {
          missingItems.add('vehicle_documents');
        }
      }

      final canGoOnline = hasApprovedVehicle;

      String? reason;
      if (!canGoOnline) {
        if (hasSubmittedVehicle) {
          reason = 'Vehicle documents under review';
        } else {
          reason = 'Please upload and submit vehicle documents';
        }
      }

      AppLogger.debug(
        'Stream eligibility: canGoOnline=$canGoOnline, hasApproved=$hasApprovedVehicle',
        tag: 'DocumentVerificationService',
      );

      return OnlineEligibility(
        canGoOnline: canGoOnline,
        reason: reason,
        missingItems: missingItems,
      );
    });
  }

  /// Update verification status (for admin use or testing)
  Future<Result<void>> updateVerificationStatus({
    required String userId,
    required String status,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'verificationStatus': status,
      };

      if (status == 'approved') {
        updateData['verificationApprovedAt'] = FieldValue.serverTimestamp();
      }

      if (notes != null) {
        updateData['verificationNotes'] = notes;
      }

      await _firestore.collection('users').doc(userId).update(updateData);

      AppLogger.success(
        'Verification status updated to: $status',
        tag: 'DocumentVerificationService',
      );

      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      return Result.failure(exception);
    }
  }
}

/// Verification status model
class VerificationStatus {
  final String status; // pending, submitted, approved, rejected
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? notes;

  VerificationStatus({
    required this.status,
    this.submittedAt,
    this.approvedAt,
    this.notes,
  });

  factory VerificationStatus.fromMap(Map<String, dynamic> map) {
    return VerificationStatus(
      status: map['verificationStatus'] as String? ?? 'pending',
      submittedAt: _parseDateTime(map['verificationSubmittedAt']),
      approvedAt: _parseDateTime(map['verificationApprovedAt']),
      notes: map['verificationNotes'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending' || status == 'submitted';
  bool get isSubmitted => status == 'submitted';
  bool get isRejected => status == 'rejected';

  String get displayStatus {
    switch (status) {
      case 'approved':
        return 'Verified';
      case 'submitted':
        return 'Under Review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}

/// Vehicle verification info
class VehicleVerificationInfo {
  final String vehicleId;
  final String registrationNumber;
  final String documentStatus;
  final bool hasAllDocuments;

  VehicleVerificationInfo({
    required this.vehicleId,
    required this.registrationNumber,
    required this.documentStatus,
    required this.hasAllDocuments,
  });

  bool get isApproved => documentStatus == 'approved';
  bool get isPending =>
      documentStatus == 'pending' || documentStatus == 'submitted';
  bool get isRejected => documentStatus == 'rejected';

  String get displayStatus {
    switch (documentStatus) {
      case 'approved':
        return 'Approved';
      case 'submitted':
        return 'Under Review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not Uploaded';
    }
  }
}

/// Online eligibility check result
class OnlineEligibility {
  final bool canGoOnline;
  final String? reason;
  final List<String> missingItems;

  OnlineEligibility({
    required this.canGoOnline,
    this.reason,
    this.missingItems = const [],
  });
}
