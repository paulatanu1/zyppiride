import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';

class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Fetch vehicle catalog from Firestore
  Future<Result<Map<String, dynamic>>> fetchVehicleCatalog({bool useCache = false}) async {
    AppLogger.firestore('GET', 'vehicleCatalog', docId: 'india2025');

    try {
      DocumentSnapshot<Map<String, dynamic>> doc;

      if (!useCache) {
        doc = await _firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.server));

        if (!doc.exists) {
          AppLogger.debug('Server fetch failed, trying cache');
          try {
            doc = await _firestore
                .collection('vehicleCatalog')
                .doc('india2025')
                .get(const GetOptions(source: Source.cache));
          } catch (e) {
            AppLogger.warning('Cache fetch also failed');
            return Result.failure(DatabaseException.notFound('Vehicle catalog'));
          }
        }
      } else {
        doc = await _firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.cache));
      }

      if (doc.exists && doc.data() != null) {
        AppLogger.success('Vehicle catalog loaded');
        return Result.success(doc.data()!);
      }

      return Result.failure(DatabaseException.notFound('Vehicle catalog'));
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'fetchVehicleCatalog');
      return Result.failure(exception);
    }
  }

  // Upload images to Firebase Storage with progress tracking
  Future<Result<List<String>>> uploadVehicleImages({
    required List<File> images,
    required String userId,
    required Function(double, String) onProgress,
  }) async {
    AppLogger.info('Uploading ${images.length} vehicle images for user: $userId');

    try {
      final List<String> uploadedUrls = [];
      int uploadedCount = 0;
      int totalImages = images.length;

      for (var image in images) {
        final ref = _storage.ref().child(
            'vehicles/$userId/vehicle/${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = ref.putFile(image);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          final overallProgress = (uploadedCount + progress) / totalImages;
          onProgress(overallProgress, 'vehicle');
        });

        await uploadTask;
        final url = await ref.getDownloadURL();
        uploadedUrls.add(url);
        uploadedCount++;
        AppLogger.debug('Uploaded image $uploadedCount/$totalImages');
      }

      AppLogger.success('All ${uploadedUrls.length} images uploaded successfully');
      return Result.success(uploadedUrls);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'uploadVehicleImages');
      return Result.failure(exception);
    }
  }

  // Register vehicle in Firestore
  Future<Result<String>> registerVehicle({
    required String userId,
    required Map<String, dynamic> locationData,
    required Map<String, dynamic> vehicleDetails,
    required List<String> vehicleImageUrls,
  }) async {
    AppLogger.firestore('ADD', 'vehicles');

    try {
      final docRef = await _firestore.collection(TestMode.vehiclesCollection).add({
        'userId': userId,
        'location': locationData,
        'vehicleDetails': vehicleDetails,
        'documents': {
          'vehicleImages': vehicleImageUrls,
          'rcImages': [],
          'licenseImages': [],
          'insuranceImages': [],
          'pucImages': [],
        },
        'documentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('Vehicle registered with ID: ${docRef.id}');

      // Keep the search-metadata document up to date so dropdown queries
      // read a single doc instead of scanning the whole collection.
      final city = (locationData['city'] as String? ?? '').trim();
      final type = (vehicleDetails['type'] as String? ?? '').trim();
      if (city.isNotEmpty || type.isNotEmpty) {
        await _updateSearchMeta(city: city, vehicleType: type);
      }

      return Result.success(docRef.id);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'registerVehicle');
      return Result.failure(exception);
    }
  }

  /// Adds the vehicle's city and type to the search-metadata document using
  /// arrayUnion — safe to call concurrently and idempotent on re-registration.
  Future<void> _updateSearchMeta({
    required String city,
    required String vehicleType,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (city.isNotEmpty) updates['cities'] = FieldValue.arrayUnion([city]);
      if (vehicleType.isNotEmpty) {
        updates['vehicleTypes'] = FieldValue.arrayUnion([vehicleType]);
      }
      await _firestore
          .doc('metadata/vehicleSearchMeta')
          .set(updates, SetOptions(merge: true));
      AppLogger.debug('Search metadata updated: city=$city, type=$vehicleType');
    } catch (e) {
      // Non-fatal — search dropdowns fall back to a limited query when the
      // metadata doc is missing or stale.
      AppLogger.warning('Could not update search metadata: $e');
    }
  }

  // Update user license details
  Future<Result<void>> updateUserLicenseDetails({
    required String userId,
    required String licenseNumber,
    required DateTime licenseValidUpto,
  }) async {
    AppLogger.firestore('UPDATE', 'users', docId: userId);

    try {
      await _firestore.collection(TestMode.usersCollection).doc(userId).update({
        'drivingLicenseNumber': licenseNumber,
        'drivingLicenseValidUpto': Timestamp.fromDate(licenseValidUpto),
      });

      AppLogger.success('User license details updated');
      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'updateUserLicenseDetails');
      return Result.failure(exception);
    }
  }

  // Check if registration number already exists
  Future<Result<bool>> isRegistrationNumberExists(String registrationNumber) async {
    AppLogger.firestore('QUERY', 'vehicles');

    try {
      final querySnapshot = await _firestore
          .collection(TestMode.vehiclesCollection)
          .where('vehicleDetails.registrationNumber',
              isEqualTo: registrationNumber.toUpperCase())
          .limit(1)
          .get();

      final exists = querySnapshot.docs.isNotEmpty;
      AppLogger.debug('Registration $registrationNumber exists: $exists');
      return Result.success(exists);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'isRegistrationNumberExists');
      return Result.failure(exception);
    }
  }
}
