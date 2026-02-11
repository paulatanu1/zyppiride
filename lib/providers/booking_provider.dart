import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import '../models/available_vehicle_model.dart';
import '../services/booking_service.dart';
import '../services/live_location_service.dart';
import '../core/utils/app_logger.dart';

// ============================================
// SERVICE PROVIDER
// ============================================

/// Provider for BookingService instance
final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

// ============================================
// BOOKING STATE
// ============================================

/// State class for booking operations
class BookingState {
  final bool isLoading;
  final bool isCreating;
  final Booking? activeBooking;
  final List<Booking> bookingHistory;
  final String? error;
  final bool hasMore;

  const BookingState({
    this.isLoading = false,
    this.isCreating = false,
    this.activeBooking,
    this.bookingHistory = const [],
    this.error,
    this.hasMore = true,
  });

  BookingState copyWith({
    bool? isLoading,
    bool? isCreating,
    Booking? activeBooking,
    List<Booking>? bookingHistory,
    String? error,
    bool? hasMore,
    bool clearActiveBooking = false,
    bool clearError = false,
  }) {
    return BookingState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      activeBooking: clearActiveBooking ? null : (activeBooking ?? this.activeBooking),
      bookingHistory: bookingHistory ?? this.bookingHistory,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ============================================
// BOOKING NOTIFIER
// ============================================

/// Notifier for managing booking state
class BookingNotifier extends StateNotifier<BookingState> {
  final BookingService _bookingService;
  StreamSubscription<Booking?>? _activeBookingSubscription;
  String? _userId;

  BookingNotifier(this._bookingService) : super(const BookingState()) {
    _initializeUser();
  }

  void _initializeUser() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid != _userId) {
        _userId = user.uid;
        _subscribeToActiveBooking();
        loadBookingHistory();
      } else if (user == null) {
        _userId = null;
        _activeBookingSubscription?.cancel();
        state = const BookingState();
      }
    });
  }

  void _subscribeToActiveBooking() {
    _activeBookingSubscription?.cancel();

    if (_userId == null) return;

    _activeBookingSubscription = _bookingService
        .getActiveBookingStream(_userId!)
        .listen(
      (booking) {
        state = state.copyWith(
          activeBooking: booking,
          clearActiveBooking: booking == null,
        );
      },
      onError: (e) {
        AppLogger.error('Active booking stream error',
            error: e, tag: 'BookingNotifier');
      },
    );
  }

  /// Create a new booking
  Future<Booking?> createBooking({
    required BookingType bookingType,
    required BookingLocation pickupLocation,
    required BookingLocation dropLocation,
    List<BookingLocation>? stops,
    required AvailableVehicle vehicle,
    required double estimatedDistance,
    required int estimatedDuration,
    required PaymentMethod paymentMethod,
    DateTime? scheduledAt,
    String? promoCode,
    String? notes,
  }) async {
    if (_userId == null) {
      state = state.copyWith(error: 'User not authenticated');
      return null;
    }

    // Check if user already has an active booking
    if (state.activeBooking != null) {
      state = state.copyWith(error: 'You already have an active booking');
      return null;
    }

    state = state.copyWith(isCreating: true, clearError: true);

    try {
      // Get user details
      final user = FirebaseAuth.instance.currentUser;

      final request = CreateBookingRequest(
        userId: _userId!,
        userPhone: user?.phoneNumber ?? '',
        userName: user?.displayName ?? 'User',
        bookingType: bookingType,
        pickupLocation: pickupLocation,
        dropLocation: dropLocation,
        stops: stops,
        vehicleId: vehicle.id,
        driverId: vehicle.userId,
        estimatedDistance: estimatedDistance,
        estimatedDuration: estimatedDuration,
        paymentMethod: paymentMethod,
        scheduledAt: scheduledAt,
        promoCode: promoCode,
        userNotes: notes,
      );

      final booking = await _bookingService.createBooking(request);

      if (booking != null) {
        state = state.copyWith(
          isCreating: false,
          activeBooking: booking,
        );
        AppLogger.info('Booking created: ${booking.bookingId}',
            tag: 'BookingNotifier');
        return booking;
      } else {
        state = state.copyWith(
          isCreating: false,
          error: 'Failed to create booking. Please try again.',
        );
        return null;
      }
    } catch (e, stack) {
      AppLogger.error('Error creating booking',
          error: e, stackTrace: stack, tag: 'BookingNotifier');
      state = state.copyWith(
        isCreating: false,
        error: 'An error occurred. Please try again.',
      );
      return null;
    }
  }

  /// Cancel current booking
  Future<bool> cancelBooking({String? reason}) async {
    if (_userId == null || state.activeBooking == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await _bookingService.cancelBooking(
        state.activeBooking!.bookingId,
        _userId!,
        reason: reason,
      );

      if (success) {
        state = state.copyWith(
          isLoading: false,
          clearActiveBooking: true,
        );
        // Refresh history
        await loadBookingHistory(refresh: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to cancel booking',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An error occurred while cancelling',
      );
      return false;
    }
  }

  /// Rate a completed booking
  Future<bool> rateBooking(String bookingId, double rating, {String? review}) async {
    if (_userId == null) return false;

    try {
      final success = await _bookingService.addUserRating(
        bookingId,
        _userId!,
        rating,
        review: review,
      );

      if (success) {
        // Refresh history to show updated rating
        await loadBookingHistory(refresh: true);
      }

      return success;
    } catch (e) {
      AppLogger.error('Error rating booking', error: e, tag: 'BookingNotifier');
      return false;
    }
  }

  /// Load booking history
  Future<void> loadBookingHistory({
    bool refresh = false,
    BookingStatus? statusFilter,
    BookingType? typeFilter,
  }) async {
    if (_userId == null) return;

    if (refresh) {
      state = state.copyWith(bookingHistory: [], hasMore: true);
    }

    if (!state.hasMore && !refresh) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final bookings = await _bookingService.getUserBookings(
        _userId!,
        statusFilter: statusFilter,
        typeFilter: typeFilter,
      );

      state = state.copyWith(
        isLoading: false,
        bookingHistory: refresh
            ? bookings
            : [...state.bookingHistory, ...bookings],
        hasMore: bookings.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load booking history',
      );
    }
  }

  /// Get a specific booking by ID
  Future<Booking?> getBooking(String bookingId) async {
    return await _bookingService.getBooking(bookingId);
  }

  /// Get user statistics
  Future<BookingStats> getUserStats() async {
    if (_userId == null) return BookingStats.empty();
    return await _bookingService.getUserStats(_userId!);
  }

  /// Check if user can create a new booking
  Future<bool> canCreateBooking() async {
    if (_userId == null) return false;
    return await _bookingService.canCreateBooking(_userId!);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Refresh active booking
  Future<void> refreshActiveBooking() async {
    if (_userId == null) return;

    final activeBooking = await _bookingService.getActiveBooking(_userId!);
    state = state.copyWith(
      activeBooking: activeBooking,
      clearActiveBooking: activeBooking == null,
    );
  }

  @override
  void dispose() {
    _activeBookingSubscription?.cancel();
    super.dispose();
  }
}

// ============================================
// DRIVER BOOKING STATE
// ============================================

/// State for driver's booking management
class DriverBookingState {
  final bool isLoading;
  final List<Booking> pendingRequests;
  final Booking? activeRide;
  final List<Booking> rideHistory;
  final String? error;

  const DriverBookingState({
    this.isLoading = false,
    this.pendingRequests = const [],
    this.activeRide,
    this.rideHistory = const [],
    this.error,
  });

  DriverBookingState copyWith({
    bool? isLoading,
    List<Booking>? pendingRequests,
    Booking? activeRide,
    List<Booking>? rideHistory,
    String? error,
    bool clearActiveRide = false,
    bool clearError = false,
  }) {
    return DriverBookingState(
      isLoading: isLoading ?? this.isLoading,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeRide: clearActiveRide ? null : (activeRide ?? this.activeRide),
      rideHistory: rideHistory ?? this.rideHistory,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for driver's booking management
class DriverBookingNotifier extends StateNotifier<DriverBookingState> {
  final BookingService _bookingService;
  final LiveLocationService _locationService;
  StreamSubscription<List<Booking>>? _pendingSubscription;
  String? _driverId;

  DriverBookingNotifier(this._bookingService, this._locationService)
      : super(const DriverBookingState()) {
    _initializeDriver();
  }

  void _initializeDriver() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid != _driverId) {
        _driverId = user.uid;
        _subscribeToPendingRequests();
        loadActiveRide();
        loadRideHistory();
      } else if (user == null) {
        _driverId = null;
        _pendingSubscription?.cancel();
        state = const DriverBookingState();
      }
    });
  }

  void _subscribeToPendingRequests() {
    _pendingSubscription?.cancel();

    if (_driverId == null) return;

    _pendingSubscription = _bookingService
        .getDriverPendingBookingsStream(_driverId!)
        .listen(
      (bookings) {
        state = state.copyWith(pendingRequests: bookings);
      },
      onError: (e) {
        AppLogger.error('Pending bookings stream error',
            error: e, tag: 'DriverBookingNotifier');
      },
    );
  }

  /// Accept a booking request
  Future<bool> acceptBooking(String bookingId) async {
    if (_driverId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await _bookingService.acceptBooking(bookingId, _driverId!);

      if (success) {
        await loadActiveRide();
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to accept booking',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An error occurred',
      );
      return false;
    }
  }

  /// Reject a booking request
  Future<bool> rejectBooking(String bookingId, {String? reason}) async {
    if (_driverId == null) return false;

    try {
      return await _bookingService.rejectBooking(
        bookingId,
        _driverId!,
        reason: reason,
      );
    } catch (e) {
      return false;
    }
  }

  /// Mark as arrived at pickup
  Future<bool> arrivedAtPickup(String bookingId) async {
    if (_driverId == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final success = await _bookingService.driverArrived(bookingId, _driverId!);
      await loadActiveRide();
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// Start the trip with OTP verification
  Future<bool> startTrip(String bookingId, String otp) async {
    if (_driverId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await _bookingService.startTrip(bookingId, _driverId!, otp);

      if (success) {
        await loadActiveRide();
        state = state.copyWith(isLoading: false);

        // Start location tracking when trip starts
        _locationService.startTracking(
          bookingId: bookingId,
          driverId: _driverId!,
        );
        AppLogger.info('Started location tracking for trip', tag: 'DriverBooking');

        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid OTP. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start trip',
      );
      return false;
    }
  }

  /// Complete the trip
  Future<bool> completeTrip(
    String bookingId, {
    double? actualDistance,
    int? actualDuration,
    double? waitingMinutes,
    double? tollCharges,
  }) async {
    if (_driverId == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      // Stop location tracking before completing trip
      await _locationService.stopTracking();
      AppLogger.info('Stopped location tracking for completed trip', tag: 'DriverBooking');

      final success = await _bookingService.completeTrip(
        bookingId,
        _driverId!,
        actualDistance: actualDistance,
        actualDuration: actualDuration,
        waitingMinutes: waitingMinutes,
        tollCharges: tollCharges,
      );

      if (success) {
        state = state.copyWith(
          isLoading: false,
          clearActiveRide: true,
        );
        await loadRideHistory(refresh: true);
        return true;
      }

      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// Rate the user after trip
  Future<bool> rateUser(String bookingId, double rating, {String? review}) async {
    if (_driverId == null) return false;

    return await _bookingService.addDriverRating(
      bookingId,
      _driverId!,
      rating,
      review: review,
    );
  }

  /// Load active ride
  Future<void> loadActiveRide() async {
    if (_driverId == null) return;

    final activeRide = await _bookingService.getDriverActiveBooking(_driverId!);
    state = state.copyWith(
      activeRide: activeRide,
      clearActiveRide: activeRide == null,
    );
  }

  /// Load ride history
  Future<void> loadRideHistory({bool refresh = false}) async {
    if (_driverId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final bookings = await _bookingService.getDriverBookings(_driverId!);
      state = state.copyWith(
        isLoading: false,
        rideHistory: bookings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Get driver statistics
  Future<BookingStats> getDriverStats() async {
    if (_driverId == null) return BookingStats.empty();
    return await _bookingService.getDriverStats(_driverId!);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }
}

// ============================================
// PROVIDERS
// ============================================

/// Main booking provider for users
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  final bookingService = ref.watch(bookingServiceProvider);
  return BookingNotifier(bookingService);
});

/// Live location service provider
final _liveLocationServiceProvider = Provider<LiveLocationService>((ref) {
  final service = LiveLocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Driver booking provider
final driverBookingProvider =
    StateNotifierProvider<DriverBookingNotifier, DriverBookingState>((ref) {
  final bookingService = ref.watch(bookingServiceProvider);
  final locationService = ref.watch(_liveLocationServiceProvider);
  return DriverBookingNotifier(bookingService, locationService);
});

/// Active booking stream provider
final activeBookingStreamProvider = StreamProvider<Booking?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.getActiveBookingStream(user.uid);
});

/// Single booking provider (for viewing specific booking)
final bookingDetailProvider =
    FutureProvider.family<Booking?, String>((ref, bookingId) async {
  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getBooking(bookingId);
});

/// Booking stream provider (for real-time updates on specific booking)
final bookingStreamProvider =
    StreamProvider.family<Booking?, String>((ref, bookingId) {
  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.getBookingStream(bookingId);
});

/// User booking stats provider
final userBookingStatsProvider = FutureProvider<BookingStats>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return BookingStats.empty();

  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getUserStats(user.uid);
});

/// Driver booking stats provider
final driverBookingStatsProvider = FutureProvider<BookingStats>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return BookingStats.empty();

  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getDriverStats(user.uid);
});

/// Driver pending requests stream
final driverPendingRequestsProvider = StreamProvider<List<Booking>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.getDriverPendingBookingsStream(user.uid);
});

/// Can create booking check
final canCreateBookingProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.canCreateBooking(user.uid);
});
