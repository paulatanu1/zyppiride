import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Fetch vehicle catalog from Firestore
  Future<Map<String, dynamic>?> fetchVehicleCatalog({bool useCache = false}) async {
    try {
      DocumentSnapshot<Map<String, dynamic>?>? doc;

      if (!useCache) {
        doc = await _firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.server));

        if (doc == null || !doc.exists) {
          try {
            doc = await _firestore
                .collection('vehicleCatalog')
                .doc('india2025')
                .get(const GetOptions(source: Source.cache));

            if (!doc.exists) doc = null;
          } catch (e) {
            doc = null;
          }
        }
      } else {
        doc = await _firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get(const GetOptions(source: Source.cache));
      }

      if (doc?.exists == true) {
        return doc!.data();
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Upload images to Firebase Storage with progress tracking
  Future<List<String>> uploadVehicleImages({
    required List<File> images,
    required String userId,
    required Function(double, String) onProgress,
  }) async {
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
    }

    return uploadedUrls;
  }

  // Register vehicle in Firestore
  Future<String> registerVehicle({
    required String userId,
    required Map<String, dynamic> locationData,
    required Map<String, dynamic> vehicleDetails,
    required List<String> vehicleImageUrls,
  }) async {
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

    return docRef.id;
  }

  // Update user license details
  Future<void> updateUserLicenseDetails({
    required String userId,
    required String licenseNumber,
    required DateTime licenseValidUpto,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'drivingLicenseNumber': licenseNumber,
      'drivingLicenseValidUpto': Timestamp.fromDate(licenseValidUpto),
    });
  }

  // Check if registration number already exists
  Future<bool> isRegistrationNumberExists(String registrationNumber) async {
    final querySnapshot = await _firestore
        .collection('vehicles')
        .where('vehicleDetails.registrationNumber',
            isEqualTo: registrationNumber.toUpperCase())
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }
}
