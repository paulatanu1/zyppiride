import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/available_vehicle_model.dart';
import '../core/constants/test_mode.dart';
import '../core/utils/app_logger.dart';
import '../core/errors/errors.dart';
import '../core/utils/pagination.dart';

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
      );

      // 4. Generate OTP for ride verification
      final rideOtp = _generateOtp();

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
        rideOtp: rideOtp,
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
  Future<bool> updateStatus(
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

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to update booking status',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Driver accepts booking
  Future<bool> acceptBooking(String bookingId, String driverId) async {
    try {
      // Verify this booking belongs to this driver
      final booking = await getBooking(bookingId);
      if (booking == null || booking.driver.driverId != driverId) {
        return false;
      }

      if (booking.status != BookingStatus.pending) {
        return false;
      }

      return await updateStatus(bookingId, BookingStatus.confirmed);
    } catch (e, stack) {
      AppLogger.error('Failed to accept booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Driver rejects booking
  Future<bool> rejectBooking(String bookingId, String driverId,
      {String? reason}) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.driver.driverId != driverId) {
        return false;
      }

      if (booking.status != BookingStatus.pending) {
        return false;
      }

      await _bookingsRef.doc(bookingId).update({
        'status': BookingStatus.rejected.name,
        'cancellationReason': reason ?? 'Driver rejected the booking',
        'cancelledBy': 'driver',
        'cancelledAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to reject booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Driver starts trip (arrived at pickup)
  Future<bool> driverArrived(String bookingId, String driverId) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.driver.driverId != driverId) {
        return false;
      }

      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.driverArriving) {
        return false;
      }

      return await updateStatus(bookingId, BookingStatus.arrived);
    } catch (e, stack) {
      AppLogger.error('Failed to update driver arrived',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Start the trip (after OTP verification)
  Future<bool> startTrip(String bookingId, String driverId, String otp) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.driver.driverId != driverId) {
        return false;
      }

      if (booking.status != BookingStatus.arrived) {
        return false;
      }

      // Verify OTP
      if (booking.rideOtp != otp) {
        AppLogger.warning('Invalid OTP for booking $bookingId',
            tag: 'BookingService');
        return false;
      }

      return await updateStatus(bookingId, BookingStatus.inProgress);
    } catch (e, stack) {
      AppLogger.error('Failed to start trip',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Complete the trip
  Future<bool> completeTrip(
    String bookingId,
    String driverId, {
    double? actualDistance,
    int? actualDuration,
    double? waitingMinutes,
    double? tollCharges,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.driver.driverId != driverId) {
        return false;
      }

      if (booking.status != BookingStatus.inProgress) {
        return false;
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
          );

          updateData['fareDetails'] = newFare.toMap();
          updateData['estimatedDistance'] = actualDistance;
          updateData['estimatedDuration'] = actualDuration;
        }
      }

      await _bookingsRef.doc(bookingId).update(updateData);

      AppLogger.info('Trip completed: $bookingId', tag: 'BookingService');

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to complete trip',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// User cancels booking
  Future<bool> cancelBooking(
    String bookingId,
    String userId, {
    String? reason,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.userId != userId) {
        return false;
      }

      if (!booking.canCancel) {
        AppLogger.warning('Booking $bookingId cannot be cancelled',
            tag: 'BookingService');
        return false;
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

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to cancel booking',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Update payment status
  Future<bool> updatePaymentStatus(
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
      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to update payment status',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
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
      final booking = await getBooking(bookingId);
      if (booking == null) {
        return Result.failure(DatabaseException.notFound('Booking'));
      }
      if (booking.driver.driverId != driverId) {
        return Result.failure(
          const AuthException(message: 'Only the assigned driver can record payment'),
        );
      }
      if (booking.status != BookingStatus.completed) {
        return Result.failure(
          ValidationException(message: 'Payment can only be recorded on a completed trip'),
        );
      }

      final totalFare = booking.fareDetails.totalFare;
      final alreadyReceived = (booking.amountReceived ?? 0.0);
      final remaining = (totalFare - alreadyReceived - amountReceived).clamp(0.0, totalFare);
      final newTotal = alreadyReceived + amountReceived;
      final isPaid = remaining <= 0;

      await _bookingsRef.doc(bookingId).update({
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

      AppLogger.success('Payment recorded: ₹$amountReceived for $bookingId', tag: 'BookingService');
      return Result.success(null);
    } catch (e, stack) {
      final exception = ErrorHandler.handle(e, stack);
      AppLogger.logException(exception, context: 'recordPaymentReceived');
      return Result.failure(exception);
    }
  }

  /// Add user rating and review
  Future<bool> addUserRating(
    String bookingId,
    String userId,
    double rating, {
    String? review,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.userId != userId) {
        return false;
      }

      if (!booking.canRate) {
        return false;
      }

      await _bookingsRef.doc(bookingId).update({
        'userRating': rating,
        'userReview': review,
        'updatedAt': Timestamp.now(),
      });

      // Update driver's average rating (simplified)
      await _updateDriverRating(booking.driver.driverId, rating);

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to add user rating',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
    }
  }

  /// Add driver rating for user
  Future<bool> addDriverRating(
    String bookingId,
    String driverId,
    double rating, {
    String? review,
  }) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null || booking.driver.driverId != driverId) {
        return false;
      }

      if (booking.status != BookingStatus.completed) {
        return false;
      }

      await _bookingsRef.doc(bookingId).update({
        'driverRating': rating,
        'driverReview': review,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to add driver rating',
          error: e, stackTrace: stack, tag: 'BookingService');
      return false;
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
  String _generateOtp() {
    return (100000 + Random().nextInt(900000)).toString();
  }

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
