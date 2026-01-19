import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
      final docRef = await _firestore.collection('vehicles').add({
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
      return Result.success(docRef.id);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'registerVehicle');
      return Result.failure(exception);
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
      await _firestore.collection('users').doc(userId).update({
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
          .collection('vehicles')
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
