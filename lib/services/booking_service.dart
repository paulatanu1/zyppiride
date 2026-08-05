
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/pagination.dart';
import '../models/available_vehicle_model.dart';
import '../models/booking_model.dart';
import '../utils/fare_calculator.dart';

/// Outcome of a server-side OTP verification call.
/// Returned by [BookingService.startTrip] so the caller can surface the
/// server-authoritative lockout / attempts-remaining to the driver UI.
class StartTripResult {
  final bool success;
  final bool invalidOtp;
  final bool locked;
  final int? attemptsRemaining;
  final int? lockedRemainingSeconds;
  final String? errorMessage;

  const StartTripResult._({
    required this.success,
    this.invalidOtp = false,
    this.locked = false,
    this.attemptsRemaining,
    this.lockedRemainingSeconds,
    this.errorMessage,
  });

  factory StartTripResult.ok() => const StartTripResult._(success: true);
  factory StartTripResult.invalid(int? remaining, bool locked) =>
      StartTripResult._(
        success: false,
        invalidOtp: true,
        locked: locked,
        attemptsRemaining: remaining,
      );
  factory StartTripResult.lockedOut(int? seconds) => StartTripResult._(
        success: false,
        locked: true,
        lockedRemainingSeconds: seconds,
      );
  factory StartTripResult.error(String message) =>
      StartTripResult._(success: false, errorMessage: message);
}

/// Service for managing bookings in Firestore
class BookingService {
  final FirebaseFirestore _firestore;

  BookingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String get _collection => TestMode.bookingsCollection;
  String get _vehiclesCollection => TestMode.vehiclesCollection;
  String get _usersCollection => TestMode.usersCollection;

  /// Collection reference
  CollectionReference<Map<String, dynamic>> get _bookingsRef =>
      _firestore.collection(_collection);

  // ============================================
  // CREATE OPERATIONS
  // ============================================

  /// Create a new booking
  Future<Booking?> createBooking(CreateBookingRequest request) async {
    try {
      // 1. Get vehicle details
      final vehicleDoc = await _firestore
          .collection(_vehiclesCollection)
          .doc(request.vehicleId)
          .get();

      if (!vehicleDoc.exists) {
        AppLogger.error('Vehicle not found',
            error: 'Vehicle ID: ${request.vehicleId}', tag: 'BookingService');
        return null;
      }

      final vehicle = AvailableVehicle.fromFirestore(vehicleDoc);

      // 2. Get driver/owner details
      final driverDoc = await _firestore
          .collection(_usersCollection)
          .doc(request.driverId)
          .get();

      final driverData = driverDoc.data() ?? {};

      // 3. Calculate fare
      final fareDetails = FareDetails.calculate(
        baseFare: vehicle.pricing.basePrice,
        perKmRate: vehicle.pricing.perKmRate,
        distanceKm: request.estimatedDistance,
        promoCode: request.promoCode,
        promoDiscount: await _getPromoDiscount(request.promoCode),
        isNightTime: FareCalculator.isNightTime(),
        isPeakHour: FareCalculator.isPeakHour(),
        minimumFare: vehicle.pricing.minimumFare,
      );

      // 4. Ride OTP is generated server-side by the onBookingCreated
      //    Cloud Function and stored in bookings/{id}/private/otp so the
      //    driver's client can never read it (W1).

      // 5. Create booking document
      final now = DateTime.now();
      final docRef = _bookingsRef.doc();

      final booking = Booking(
        bookingId: docRef.id,
        userId: request.userId,
        userPhone: request.userPhone,
        userName: request.userName,
        bookingType: request.bookingType,
        status: BookingStatus.pending,
        pickupLocation: request.pickupLocation,
        dropLocation: request.dropLocation,
        stops: request.stops,
        estimatedDistance: request.estimatedDistance,
        estimatedDuration: request.estimatedDuration,
        estimatedArrival: _calculateEta(request.estimatedDuration),
        vehicle: BookingVehicleDetails(
          vehicleId: vehicle.id,
          type: vehicle.vehicleInfo.type,
          brand: vehicle.vehicleInfo.brand,
          model: vehicle.vehicleInfo.model,
          registrationNumber: vehicle.vehicleInfo.registrationNumber,
          color: vehicle.vehicleInfo.color,
          seatingCapacity: vehicle.vehicleInfo.seatingCapacity,
          hasAC: vehicle.vehicleInfo.hasAC,
          imageUrl: vehicle.vehicleImages.isNotEmpty
              ? vehicle.vehicleImages.first
              : null,
        ),
        driver: BookingDriverDetails(
          driverId: request.driverId,
          name: driverData['fullName'] ?? vehicle.driverName,
          phoneNumber: driverData['mobile'],
          photoUrl: driverData['profileImageUrl'],
          rating: vehicle.driverRating,
          totalTrips: vehicle.totalTrips,
        ),
        fareDetails: fareDetails,
        paymentMethod: request.paymentMethod,
        paymentStatus: PaymentStatus.pending,
        scheduledAt: request.scheduledAt,
        isScheduled: request.isScheduled,
        createdAt: now,
        updatedAt: now,
        userNotes: request.userNotes,
      );

      await docRef.set(booking.toMap());

      AppLogger.info('Booking created: ${docRef.id}', tag: 'BookingService');

      return booking;
    } catch (e, stack) {
      AppLogger.error('Failed to create booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return null;
    }
  }

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Get a booking by ID
  Future<Booking?> getBooking(String bookingId) async {
    try {
      final doc = await _bookingsRef.doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return null;
    }
  }

  /// Get booking stream for real-time updates
  Stream<Booking?> getBookingStream(String bookingId) {
    return _bookingsRef.doc(bookingId).snapshots().map((doc) {
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Get user's active booking (if any)
  Future<Booking?> getActiveBooking(String userId) async {
    try {
      final snapshot = await _bookingsRef
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [
            BookingStatus.pending.name,
            BookingStatus.confirmed.name,
            BookingStatus.driverArriving.name,
            BookingStatus.arrived.name,
            BookingStatus.inProgress.name,
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Booking.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get active booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return null;
    }
  }

  /// Stream user's active booking
  Stream<Booking?> getActiveBookingStream(String userId) {
    return _bookingsRef
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [
          BookingStatus.pending.name,
          BookingStatus.confirmed.name,
          BookingStatus.driverArriving.name,
          BookingStatus.arrived.name,
          BookingStatus.inProgress.name,
        ])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Booking.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  /// Get user's booking history with pagination
  Future<List<Booking>> getUserBookings(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    BookingStatus? statusFilter,
    BookingType? typeFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _bookingsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }

      if (typeFilter != null) {
        query = query.where('bookingType', isEqualTo: typeFilter.name);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get user bookings',
          error: e, stackTrace: stack, tag: 'BookingService');
      return [];
    }
  }

  /// Paginated user booking history — returns items + cursor for next page.
  Future<PaginatedResult<Booking>> getUserBookingsPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    BookingStatus? statusFilter,
    BookingType? typeFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _bookingsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }
      if (typeFilter != null) {
        query = query.where('bookingType', isEqualTo: typeFilter.name);
      }
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit);

      final snapshot = await query.get();
      final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      return PaginatedResult(
        items: bookings,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: bookings.length >= limit,
      );
    } catch (e, stack) {
      AppLogger.error('Failed to get paginated user bookings',
          error: e, stackTrace: stack, tag: 'BookingService');
      return const PaginatedResult(items: [], hasMore: false);
    }
  }

  /// Stream user's booking history
  Stream<List<Booking>> getUserBookingsStream(String userId, {int limit = 20}) {
    return _bookingsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  /// Get driver's pending bookings (requests)
  Future<List<Booking>> getDriverPendingBookings(String driverId) async {
    try {
      final snapshot = await _bookingsRef
          .where('driver.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: BookingStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get driver pending bookings',
          error: e, stackTrace: stack, tag: 'BookingService');
      return [];
    }
  }

  /// Get driver's active booking
  Future<Booking?> getDriverActiveBooking(String driverId) async {
    try {
      final snapshot = await _bookingsRef
          .where('driver.driverId', isEqualTo: driverId)
          .where('status', whereIn: [
            BookingStatus.confirmed.name,
            BookingStatus.driverArriving.name,
            BookingStatus.arrived.name,
            BookingStatus.inProgress.name,
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Booking.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get driver active booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return null;
    }
  }

  /// Stream driver's pending bookings
  Stream<List<Booking>> getDriverPendingBookingsStream(String driverId) {
    return _bookingsRef
        .where('driver.driverId', isEqualTo: driverId)
        .where('status', isEqualTo: BookingStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  /// Get driver's booking history
  Future<List<Booking>> getDriverBookings(
    String driverId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _bookingsRef
          .where('driver.driverId', isEqualTo: driverId)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get driver bookings',
          error: e, stackTrace: stack, tag: 'BookingService');
      return [];
    }
  }

  // ============================================
  // UPDATE OPERATIONS
  // ============================================

  /// Update booking status
  Future<Result<void>> updateStatus(
    String bookingId,
    BookingStatus newStatus, {
    String? cancellationReason,
    String? cancelledBy,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': Timestamp.now(),
      };

      // Add timestamp for specific status changes
      switch (newStatus) {
        case BookingStatus.confirmed:
          updateData['confirmedAt'] = Timestamp.now();
          break;
        case BookingStatus.inProgress:
          updateData['startedAt'] = Timestamp.now();
          break;
        case BookingStatus.completed:
          updateData['completedAt'] = Timestamp.now();
          break;
        case BookingStatus.cancelled:
          updateData['cancelledAt'] = Timestamp.now();
          if (cancellationReason != null) {
            updateData['cancellationReason'] = cancellationReason;
          }
          if (cancelledBy != null) {
            updateData['cancelledBy'] = cancelledBy;
          }
          break;
        default:
          break;
      }

      await _bookingsRef.doc(bookingId).update(updateData);

      AppLogger.info('Booking $bookingId status updated to ${newStatus.name}',
          tag: 'BookingService');

      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'updateStatus');
      return Result.failure(exception);
    }
  }

  /// Driver accepts booking
  Future<Result<void>> acceptBooking(String bookingId, String driverId) async {
    try {
      // Verify this booking belongs to this driver
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'This booking is not assigned to you'),
        );
      }

      if (booking.status != BookingStatus.pending) {
        return Result.failure(
          ValidationException(
            message: 'Booking is no longer pending (status: ${booking.status.name})',
          ),
        );
      }

      return await updateStatus(bookingId, BookingStatus.confirmed);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'acceptBooking');
      return Result.failure(exception);
    }
  }

  /// Driver rejects booking
  Future<Result<void>> rejectBooking(String bookingId, String driverId,
      {String? reason}) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'This booking is not assigned to you'),
        );
      }

      if (booking.status != BookingStatus.pending) {
        return Result.failure(
          ValidationException(
            message: 'Booking is no longer pending (status: ${booking.status.name})',
          ),
        );
      }

      await _bookingsRef.doc(bookingId).update({
        'status': BookingStatus.rejected.name,
        'cancellationReason': reason ?? 'Driver rejected the booking',
        'cancelledBy': 'driver',
        'cancelledAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'rejectBooking');
      return Result.failure(exception);
    }
  }

  /// Driver starts trip (arrived at pickup)
  Future<Result<void>> driverArrived(String bookingId, String driverId) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'This booking is not assigned to you'),
        );
      }

      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.driverArriving) {
        return Result.failure(
          ValidationException(
            message: 'Cannot mark arrived from status ${booking.status.name}',
          ),
        );
      }

      return await updateStatus(bookingId, BookingStatus.arrived);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'driverArrived');
      return Result.failure(exception);
    }
  }

  /// Driver cancels a booking they already accepted.
  ///
  /// Distinct from [rejectBooking] (pending-only, before acceptance): this
  /// covers confirmed/driverArriving/arrived — after the driver committed to
  /// the ride but before the trip started. firestore.rules' isDriverTransitionValid
  /// permits this exact set of source statuses to move to 'cancelled'; once
  /// inProgress, the trip must be completed rather than cancelled.
  Future<Result<void>> driverCancelBooking(
    String bookingId,
    String driverId, {
    String? reason,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'This booking is not assigned to you'),
        );
      }

      const cancellableStatuses = {
        BookingStatus.confirmed,
        BookingStatus.driverArriving,
        BookingStatus.arrived,
      };
      if (!cancellableStatuses.contains(booking.status)) {
        return Result.failure(
          ValidationException(
            message: 'Cannot cancel from status ${booking.status.name}',
          ),
        );
      }

      await _bookingsRef.doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'cancellationReason': reason ?? 'Cancelled by driver',
        'cancelledBy': 'driver',
        'cancelledAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      AppLogger.info('Booking cancelled by driver: $bookingId', tag: 'BookingService');
      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'driverCancelBooking');
      return Result.failure(exception);
    }
  }

  /// Start the trip after OTP verification.
  ///
  /// Verification runs in the [verifyRideOtp] Cloud Function so that the OTP
  /// comparison, attempt counter, and lockout cannot be bypassed by a modified
  /// driver client (V-04). The function flips status → inProgress on success;
  /// the [driverId] parameter is no longer needed because the function reads
  /// it from `auth.uid`, but kept for source-compatibility with callers.
  Future<StartTripResult> startTrip(
    String bookingId,
    String driverId,
    String otp,
  ) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyRideOtp');
      await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'otp': otp,
      });
      return StartTripResult.ok();
    } on FirebaseFunctionsException catch (e) {
      AppLogger.warning(
        'verifyRideOtp failed: ${e.code} ${e.message}',
        tag: 'BookingService',
      );
      switch (e.code) {
        case 'invalid-argument':
          final details = e.details;
          if (details is Map) {
            final locked = details['locked'] == true;
            final remaining = (details['remaining'] as num?)?.toInt();
            return StartTripResult.invalid(remaining, locked);
          }
          return StartTripResult.invalid(null, false);
        case 'resource-exhausted':
          final details = e.details;
          int? remainingSec;
          if (details is Map) {
            remainingSec = (details['remainingSec'] as num?)?.toInt();
          }
          return StartTripResult.lockedOut(remainingSec);
        case 'failed-precondition':
        case 'permission-denied':
        case 'not-found':
        case 'unauthenticated':
          return StartTripResult.error(e.message ?? e.code);
        default:
          return StartTripResult.error(e.message ?? 'Could not verify OTP.');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to start trip',
          error: e, stackTrace: stack, tag: 'BookingService');
      return StartTripResult.error('Could not start trip. Try again.');
    }
  }

  /// Complete the trip
  Future<Result<void>> completeTrip(
    String bookingId,
    String driverId, {
    double? actualDistance,
    int? actualDuration,
    double? waitingMinutes,
    double? tollCharges,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'This booking is not assigned to you'),
        );
      }

      if (booking.status != BookingStatus.inProgress) {
        return Result.failure(
          ValidationException(
            message: 'Cannot complete trip from status ${booking.status.name}',
          ),
        );
      }

      // Recalculate fare if actual values differ
      Map<String, dynamic> updateData = {
        'status': BookingStatus.completed.name,
        'completedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      if (actualDistance != null || waitingMinutes != null || tollCharges != null) {
        // Get vehicle pricing for recalculation
        final vehicleDoc = await _firestore
            .collection(_vehiclesCollection)
            .doc(booking.vehicle.vehicleId)
            .get();

        if (vehicleDoc.exists) {
          final vehicle = AvailableVehicle.fromFirestore(vehicleDoc);
          final newFare = FareDetails.calculate(
            baseFare: vehicle.pricing.basePrice,
            perKmRate: vehicle.pricing.perKmRate,
            distanceKm: actualDistance ?? booking.estimatedDistance ?? 0,
            waitingMinutes: waitingMinutes ?? 0,
            tollCharges: tollCharges ?? 0,
            promoCode: booking.fareDetails.promoCode,
            promoDiscount: booking.fareDetails.promoDiscount,
            isNightTime: FareCalculator.isNightTime(),
            isPeakHour: FareCalculator.isPeakHour(),
            minimumFare: vehicle.pricing.minimumFare,
          );

          updateData['fareDetails'] = newFare.toMap();
          updateData['estimatedDistance'] = actualDistance;
          updateData['estimatedDuration'] = actualDuration;
        }
      }

      await _bookingsRef.doc(bookingId).update(updateData);

      AppLogger.info('Trip completed: $bookingId', tag: 'BookingService');

      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'completeTrip');
      return Result.failure(exception);
    }
  }

  /// User cancels booking
  Future<Result<void>> cancelBooking(
    String bookingId,
    String userId, {
    String? reason,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.userId != userId) {
        return Result.failure(
          const AuthException(message: 'This booking does not belong to you'),
        );
      }

      if (!booking.canCancel) {
        AppLogger.warning('Booking $bookingId cannot be cancelled',
            tag: 'BookingService');
        return Result.failure(
          ValidationException(
            message: 'Booking can no longer be cancelled (status: ${booking.status.name})',
          ),
        );
      }

      // Calculate cancellation fee if applicable
      double? cancellationFee;
      if (booking.status == BookingStatus.confirmed) {
        // Charge cancellation fee if driver already confirmed
        cancellationFee = booking.fareDetails.baseFare * 0.2; // 20% of base fare
      }

      await _bookingsRef.doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'cancellationReason': reason ?? 'Cancelled by user',
        'cancelledBy': 'user',
        'cancelledAt': Timestamp.now(),
        'cancellationFee': cancellationFee,
        'updatedAt': Timestamp.now(),
      });

      AppLogger.info('Booking cancelled: $bookingId', tag: 'BookingService');

      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'cancelBooking');
      return Result.failure(exception);
    }
  }

  /// Update payment status
  Future<Result<void>> updatePaymentStatus(
    String bookingId,
    PaymentStatus status, {
    String? transactionId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'paymentStatus': status.name,
        'updatedAt': Timestamp.now(),
      };

      if (transactionId != null) {
        updateData['paymentTransactionId'] = transactionId;
      }

      await _bookingsRef.doc(bookingId).update(updateData);
      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'updatePaymentStatus');
      return Result.failure(exception);
    }
  }

  /// Record manual cash payment received after trip completion.
  /// Only the assigned driver can call this, and only on completed bookings.
  Future<Result<void>> recordPaymentReceived({
    required String bookingId,
    required String driverId,
    required double amountReceived,
  }) async {
    try {
      final docRef = _bookingsRef.doc(bookingId);

      // Read-modify-write must be atomic: a double-tap or a client retry
      // after a timed-out (but server-applied) request must not credit the
      // same payment twice.
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          throw DatabaseException.notFound('Booking');
        }
        final booking = Booking.fromFirestore(snap);

        if (booking.driver.driverId != driverId) {
          throw const AuthException(
              message: 'Only the assigned driver can record payment');
        }
        if (booking.status != BookingStatus.completed) {
          throw ValidationException(
              message: 'Payment can only be recorded on a completed trip');
        }

        final totalFare = booking.fareDetails.totalFare;
        final alreadyReceived = booking.amountReceived ?? 0.0;
        final remaining =
            (totalFare - alreadyReceived - amountReceived).clamp(0.0, totalFare);
        final newTotal = alreadyReceived + amountReceived;
        final isPaid = remaining <= 0;

        tx.update(docRef, {
          'amountReceived': newTotal,
          'remainingAmount': remaining,
          'paymentStatus': isPaid
              ? PaymentStatus.completed.name
              : PaymentStatus.pending.name,
          'paymentReceivedAt': Timestamp.now(),
          'paymentReceivedBy': driverId,
          'paymentRecordedManually': true,
          'updatedAt': Timestamp.now(),
        });
      });

      AppLogger.success('Payment recorded: ₹$amountReceived for $bookingId', tag: 'BookingService');
      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'recordPaymentReceived');
      return Result.failure(exception);
    }
  }

  /// Add user rating and review
  Future<Result<void>> addUserRating(
    String bookingId,
    String userId,
    double rating, {
    String? review,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.userId != userId) {
        return Result.failure(
          const AuthException(message: 'This booking does not belong to you'),
        );
      }

      if (!booking.canRate) {
        return Result.failure(
          ValidationException(message: 'This booking cannot be rated'),
        );
      }

      await _bookingsRef.doc(bookingId).update({
        'userRating': rating,
        'userReview': review,
        'updatedAt': Timestamp.now(),
      });

      // Update driver's average rating (simplified)
      await _updateDriverRating(booking.driver.driverId, rating);

      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'addUserRating');
      return Result.failure(exception);
    }
  }

  /// Add driver rating for user
  Future<Result<void>> addDriverRating(
    String bookingId,
    String driverId,
    double rating, {
    String? review,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'This booking is not assigned to you'),
        );
      }

      if (booking.status != BookingStatus.completed) {
        return Result.failure(
          ValidationException(message: 'Can only rate a completed trip'),
        );
      }

      await _bookingsRef.doc(bookingId).update({
        'driverRating': rating,
        'driverReview': review,
        'updatedAt': Timestamp.now(),
      });

      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'addDriverRating');
      return Result.failure(exception);
    }
  }

  // ============================================
  // STATISTICS & ANALYTICS
  // ============================================

  /// Get user's booking statistics
  Future<BookingStats> getUserStats(String userId) async {
    try {
      final completedQuery = await _bookingsRef
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: BookingStatus.completed.name)
          .count()
          .get();

      final cancelledQuery = await _bookingsRef
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: BookingStatus.cancelled.name)
          .count()
          .get();

      // Get total spent
      final completedBookings = await _bookingsRef
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: BookingStatus.completed.name)
          .get();

      double totalSpent = 0;
      double totalDistance = 0;
      for (final doc in completedBookings.docs) {
        final data = doc.data();
        final fareDetails = data['fareDetails'] as Map<String, dynamic>?;
        if (fareDetails != null) {
          totalSpent += (fareDetails['totalFare'] ?? 0).toDouble();
        }
        totalDistance += (data['estimatedDistance'] ?? 0).toDouble();
      }

      return BookingStats(
        totalBookings: (completedQuery.count ?? 0) + (cancelledQuery.count ?? 0),
        completedBookings: completedQuery.count ?? 0,
        cancelledBookings: cancelledQuery.count ?? 0,
        totalSpent: totalSpent,
        totalDistance: totalDistance,
      );
    } catch (e, stack) {
      AppLogger.error('Failed to get user stats',
          error: e, stackTrace: stack, tag: 'BookingService');
      return BookingStats.empty();
    }
  }

  /// Get driver's booking statistics
  Future<BookingStats> getDriverStats(String driverId) async {
    try {
      final completedQuery = await _bookingsRef
          .where('driver.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: BookingStatus.completed.name)
          .count()
          .get();

      final cancelledQuery = await _bookingsRef
          .where('driver.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: BookingStatus.cancelled.name)
          .count()
          .get();

      // Get total earned
      final completedBookings = await _bookingsRef
          .where('driver.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: BookingStatus.completed.name)
          .get();

      double totalEarned = 0;
      double totalDistance = 0;
      for (final doc in completedBookings.docs) {
        final data = doc.data();
        final fareDetails = data['fareDetails'] as Map<String, dynamic>?;
        if (fareDetails != null) {
          totalEarned += (fareDetails['totalFare'] ?? 0).toDouble();
        }
        totalDistance += (data['estimatedDistance'] ?? 0).toDouble();
      }

      return BookingStats(
        totalBookings: (completedQuery.count ?? 0) + (cancelledQuery.count ?? 0),
        completedBookings: completedQuery.count ?? 0,
        cancelledBookings: cancelledQuery.count ?? 0,
        totalSpent: totalEarned,
        totalDistance: totalDistance,
      );
    } catch (e, stack) {
      AppLogger.error('Failed to get driver stats',
          error: e, stackTrace: stack, tag: 'BookingService');
      return BookingStats.empty();
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Generate 6-digit OTP (900,000 combinations — significantly harder to brute-force)
  /// Calculate ETA string
  String _calculateEta(int durationMinutes) {
    if (durationMinutes < 60) {
      return '$durationMinutes mins';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (mins == 0) {
      return '$hours hr';
    }
    return '$hours hr $mins mins';
  }

  /// Get promo discount (placeholder - implement with offers service)
  Future<double?> _getPromoDiscount(String? promoCode) async {
    if (promoCode == null || promoCode.isEmpty) return null;

    try {
      final offersSnapshot = await _firestore
          .collection('offers')
          .where('code', isEqualTo: promoCode.toUpperCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (offersSnapshot.docs.isNotEmpty) {
        final offerData = offersSnapshot.docs.first.data();
        return (offerData['discount'] ?? 0).toDouble();
      }
    } catch (e) {
      AppLogger.warning('Failed to get promo discount: $e',
          tag: 'BookingService');
    }
    return null;
  }

  /// Update driver's average rating using an incremental approach.
  /// Reads current ratingSum/ratingCount from the vehicle doc and increments
  /// atomically — avoids a full collection scan on every rating.
  Future<void> _updateDriverRating(String driverId, double newRating) async {
    try {
      final vehiclesQuery = await _firestore
          .collection(_vehiclesCollection)
          .where('userId', isEqualTo: driverId)
          .get();

      if (vehiclesQuery.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final vehicleDoc in vehiclesQuery.docs) {
        final driverData =
            vehicleDoc.data()['driver'] as Map<String, dynamic>? ?? {};
        final currentSum =
            (driverData['ratingSum'] as num?)?.toDouble() ?? 0.0;
        final currentCount = (driverData['ratingCount'] as num?)?.toInt() ?? 0;
        final newSum = currentSum + newRating;
        final newCount = currentCount + 1;

        batch.update(vehicleDoc.reference, {
          'driver.ratingSum': newSum,
          'driver.ratingCount': newCount,
          'driver.rating': newSum / newCount,
          'driver.totalTrips': FieldValue.increment(1),
        });
      }
      await batch.commit();
    } catch (e) {
      AppLogger.warning('Failed to update driver rating: $e',
          tag: 'BookingService');
    }
  }

  /// Check if booking can be created (no active booking)
  Future<bool> canCreateBooking(String userId) async {
    final activeBooking = await getActiveBooking(userId);
    return activeBooking == null;
  }

  /// Expire old pending bookings.
  /// This should only be called from a Cloud Function or an admin context.
  /// Client callers must pass [adminOverride: true] to acknowledge the risk;
  /// omitting it is a no-op so accidental calls from user sessions are safe.
  Future<int> expireOldBookings({
    int minutesOld = 10,
    bool adminOverride = false,
  }) async {
    if (!adminOverride) {
      AppLogger.warning(
        'expireOldBookings called without adminOverride — skipped. '
        'Move this to a Cloud Function.',
        tag: 'BookingService',
      );
      return 0;
    }
    try {
      final cutoffTime = DateTime.now().subtract(Duration(minutes: minutesOld));

      final oldBookings = await _bookingsRef
          .where('status', isEqualTo: BookingStatus.pending.name)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldBookings.docs) {
        batch.update(doc.reference, {
          'status': BookingStatus.expired.name,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();

      AppLogger.info('Expired ${oldBookings.docs.length} old bookings',
          tag: 'BookingService');

      return oldBookings.docs.length;
    } catch (e, stack) {
      AppLogger.error('Failed to expire old bookings',
          error: e, stackTrace: stack, tag: 'BookingService');
      return 0;
    }
  }
}

/// Booking statistics model
class BookingStats {
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double totalSpent;
  final double totalDistance;

  const BookingStats({
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.totalSpent,
    required this.totalDistance,
  });

  factory BookingStats.empty() => const BookingStats(
        totalBookings: 0,
        completedBookings: 0,
        cancelledBookings: 0,
        totalSpent: 0,
        totalDistance: 0,
      );

  double get completionRate =>
      totalBookings > 0 ? (completedBookings / totalBookings) * 100 : 0;
}
