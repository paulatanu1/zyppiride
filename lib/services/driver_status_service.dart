import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';

/// Service for managing driver online/offline status
class DriverStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Toggle driver online status for all vehicles owned by the driver
  Future<Result<bool>> toggleOnlineStatus({
    required String userId,
    required bool isOnline,
  }) async {
    AppLogger.info('Setting driver $userId online status to: $isOnline');

    try {
      final batch = _firestore.batch();

      // Get all vehicles for this driver
      final vehiclesSnapshot = await _firestore
          .collection(TestMode.vehiclesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      if (vehiclesSnapshot.docs.isEmpty) {
        AppLogger.warning('No vehicles found for driver $userId');
        return Result.failure(
          DatabaseException.notFound('No vehicles registered'),
        );
      }

      // firestore.rules only allows isOnline=true writes on vehicles whose
      // own documentStatus is 'approved'. Firestore batches are all-or-nothing,
      // so including even one unapproved vehicle would deny the ENTIRE batch —
      // silently blocking the driver's already-approved vehicles from going
      // online too. Going offline has no such restriction.
      final targetDocs = isOnline
          ? vehiclesSnapshot.docs
              .where((doc) => doc.data()['documentStatus'] == 'approved')
              .toList()
          : vehiclesSnapshot.docs;

      if (isOnline && targetDocs.isEmpty) {
        AppLogger.warning('No approved vehicles found for driver $userId');
        return Result.failure(
          DatabaseException.notFound('No approved vehicles to go online with'),
        );
      }

      // Update online status for all vehicles
      for (final doc in targetDocs) {
        batch.update(doc.reference, {
          'isOnline': isOnline,
          'lastOnlineAt': isOnline ? FieldValue.serverTimestamp() : null,
          'onlineStatusUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Also update user document with online status
      batch.update(_firestore.collection(TestMode.usersCollection).doc(userId), {
        'isOnline': isOnline,
        'lastOnlineAt': isOnline ? FieldValue.serverTimestamp() : null,
      });

      await batch.commit();

      AppLogger.success(
        'Updated online status to $isOnline for ${vehiclesSnapshot.docs.length} vehicles',
      );
      return Result.success(isOnline);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'toggleOnlineStatus');
      return Result.failure(exception);
    }
  }

  /// Get current online status for a driver
  Future<Result<bool>> getOnlineStatus(String userId) async {
    AppLogger.firestore('GET', 'users', docId: '$userId (online status)');

    try {
      final userDoc = await _firestore.collection(TestMode.usersCollection).doc(userId).get();

      if (!userDoc.exists) {
        return Result.failure(DatabaseException.notFound('User'));
      }

      final isOnline = userDoc.data()?['isOnline'] ?? false;
      return Result.success(isOnline);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getOnlineStatus');
      return Result.failure(exception);
    }
  }

  /// Stream driver online status
  Stream<bool> watchOnlineStatus(String userId) {
    return _firestore
        .collection(TestMode.usersCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['isOnline'] ?? false);
  }

  /// Get online drivers count
  Future<Result<int>> getOnlineDriversCount({String? city}) async {
    AppLogger.firestore('QUERY', 'vehicles', docId: 'online count');

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(TestMode.vehiclesCollection)
          .where('isOnline', isEqualTo: true);

      if (city != null && city.isNotEmpty) {
        query = query.where('location.city', isEqualTo: city);
      }

      final snapshot = await query.count().get();
      final count = snapshot.count ?? 0;

      AppLogger.success('Found $count online drivers${city != null ? ' in $city' : ''}');
      return Result.success(count);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      AppLogger.logException(exception, context: 'getOnlineDriversCount');
      return Result.failure(exception);
    }
  }

  /// Set driver as offline when app goes to background or closes
  Future<void> setOfflineOnDisconnect(String userId) async {
    try {
      // Get all vehicles for this driver
      final vehiclesSnapshot = await _firestore
          .collection(TestMode.vehiclesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      // Update to offline
      final batch = _firestore.batch();
      for (final doc in vehiclesSnapshot.docs) {
        batch.update(doc.reference, {
          'isOnline': false,
          'onlineStatusUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.update(_firestore.collection(TestMode.usersCollection).doc(userId), {
        'isOnline': false,
      });

      await batch.commit();
      AppLogger.info('Driver $userId set to offline on disconnect');
    } catch (e) {
      AppLogger.error('Failed to set offline status: $e');
    }
  }

  /// Update driver location while online (for real-time tracking)
  Future<Result<void>> updateLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Update location for all vehicles
      final vehiclesSnapshot = await _firestore
          .collection(TestMode.vehiclesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in vehiclesSnapshot.docs) {
        batch.update(doc.reference, {
          'location.latitude': latitude,
          'location.longitude': longitude,
          'location.updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return Result.success(null);
    } catch (e, stackTrace) {
      final exception = ErrorHandler.handle(e, stackTrace);
      return Result.failure(exception);
    }
  }
}
