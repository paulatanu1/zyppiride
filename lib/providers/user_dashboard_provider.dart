import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/test_mode.dart';
import '../core/errors/errors.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/pagination.dart';
import '../models/active_booking_model.dart';
import '../models/banner_model.dart';
import '../models/offer_banner_model.dart';
import '../models/offer_model.dart';
import '../models/points_entry.dart';
import '../models/reward.dart';
import '../models/user_model.dart';

// ============================================
// FIREBASE INSTANCES
// ============================================
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ============================================
// CURRENT USER PROVIDER
// ============================================
final currentUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

// ============================================
// USER DASHBOARD PROVIDER (Fetches from Firestore)
// ============================================
final userDashboardProvider = StreamProvider<UserModel>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) {
    return Stream.value(
      UserModel(
        userId: '',
        userName: 'Guest',
        email: null,
        phoneNumber: null,
      ),
    );
  }

  // Fetch user data from Firestore 'users' collection
  return firestore
      .collection(TestMode.usersCollection)
      .doc(authUser.uid)
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists) {
      return UserModel.fromJson({
        ...snapshot.data()!,
        'userId': authUser.uid,
      });
    } else {
      // Return default user if document doesn't exist
      return UserModel(
        userId: authUser.uid,
        userName: authUser.displayName ?? 'User',
        email: authUser.email,
        phoneNumber: authUser.phoneNumber,
      );
    }
  });
});

// ============================================
// USER DASHBOARD NOTIFIER (For Manual Refresh)
// ============================================
class UserDashboardNotifier extends StateNotifier<AsyncValue<UserModel>> {
  final Ref ref;

  UserDashboardNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    ref.listen<AsyncValue<UserModel>>(
      userDashboardProvider,
          (_, next) => state = next,
    );
  }

  Future<void> refreshUserData() async {
    final firestore = ref.read(firestoreProvider);
    final authUser = ref.read(currentUserProvider).value;

    if (authUser == null) return;

    try {
      final doc = await firestore.collection(TestMode.usersCollection).doc(authUser.uid).get();
      if (doc.exists) {
        state = AsyncValue.data(
          UserModel.fromJson({
            ...doc.data()!,
            'userId': authUser.uid,
          }),
        );
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final userDashboardNotifierProvider =
StateNotifierProvider<UserDashboardNotifier, AsyncValue<UserModel>>((ref) {
  return UserDashboardNotifier(ref);
});

// ============================================
// ACTIVE BOOKING PROVIDER
// ============================================
final activeBookingProvider = StreamProvider<ActiveBooking?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) {
    return Stream.value(null);
  }

  // Query active bookings for current user — orderBy is required so that
  // the most recent booking is returned and the composite index is used.
  return firestore
      .collection(TestMode.bookingsCollection)
      .where('userId', isEqualTo: authUser.uid)
      .where('status', whereIn: ['pending', 'confirmed', 'driverArriving', 'arrived', 'inProgress'])
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    return ActiveBooking.fromJson({...data, 'bookingId': snapshot.docs.first.id});
  });
});

// ============================================
// BANNER DATA PROVIDER (with pagination)
// ============================================
const int _bannerPageSize = 10;

final bannerDataProvider = StreamProvider<List<BannerData>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) return Stream.value([]);

  AppLogger.firestore('STREAM', 'banners');

  return firestore
      .collection('banners')
      .where('isActive', isEqualTo: true)
      .orderBy('priority', descending: true)
      .limit(_bannerPageSize)
      .snapshots()
      .map((snapshot) {
    AppLogger.debug('Loaded ${snapshot.docs.length} banners');
    return snapshot.docs.map((doc) => BannerData.fromJson(doc.data())).toList();
  }).handleError((error, stackTrace) {
    AppLogger.error('Error loading banners', error: error, stackTrace: stackTrace);
    return <BannerData>[];
  });
});

// ============================================
// OFFERS PROVIDER (with pagination)
// ============================================
const int _offersPageSize = 10;

final offersProvider = StreamProvider<List<OfferData>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) return Stream.value([]);

  AppLogger.firestore('STREAM', 'offers');

  return firestore
      .collection('offers')
      .where('isActive', isEqualTo: true)
      .where('expiryDate', isGreaterThan: Timestamp.now())
      .orderBy('expiryDate')
      .limit(_offersPageSize)
      .snapshots()
      .map((snapshot) {
    AppLogger.debug('Loaded ${snapshot.docs.length} offers');
    return snapshot.docs.map((doc) => OfferData.fromJson(doc.data())).toList();
  }).handleError((error, stackTrace) {
    AppLogger.error('Error loading offers', error: error, stackTrace: stackTrace);
    return <OfferData>[];
  });
});

// ============================================
// OFFER BANNERS PROVIDER (with pagination)
// ============================================
const int _offerBannersPageSize = 10;

final offerBannersProvider = StreamProvider<List<OfferBannerData>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) return Stream.value([]);

  AppLogger.firestore('STREAM', 'offer_banners');

  return firestore
      .collection('offer_banners')
      .where('isActive', isEqualTo: true)
      .orderBy('priority', descending: true)
      .limit(_offerBannersPageSize)
      .snapshots()
      .map((snapshot) {
    final banners = snapshot.docs
        .map((doc) => OfferBannerData.fromJson(doc.data(), docId: doc.id))
        .where((banner) =>
            banner.expiryDate == null ||
            banner.expiryDate!.isAfter(DateTime.now()))
        .toList();
    AppLogger.debug('Loaded ${banners.length} offer banners');
    return banners;
  }).handleError((error, stackTrace) {
    AppLogger.error('Error loading offer banners', error: error, stackTrace: stackTrace);
    return <OfferBannerData>[];
  });
});

// ============================================
// REWARDS PROVIDERS
// ============================================

/// Snapshot of the current user's rewards fields (points, tier, coupon count).
///
/// Sources everything off [userDashboardProvider] — no extra Firestore reads.
class UserRewardsSnapshot {
  final int? totalPoints;
  final int? availableCoupons;
  final String? tier;
  final int? ridesToNextTier;
  final String? nextTier;

  const UserRewardsSnapshot({
    this.totalPoints,
    this.availableCoupons,
    this.tier,
    this.ridesToNextTier,
    this.nextTier,
  });

  bool get hasTierProgress =>
      ridesToNextTier != null && ridesToNextTier! > 0 && nextTier != null;
}

final userRewardsProvider = Provider<UserRewardsSnapshot>((ref) {
  final userAsync = ref.watch(userDashboardProvider);
  return userAsync.maybeWhen(
    data: (user) => UserRewardsSnapshot(
      totalPoints: user.totalPoints,
      availableCoupons: user.availableCoupons,
      tier: user.tier,
      ridesToNextTier: user.ridesToNextTier,
      nextTier: user.nextTier,
    ),
    orElse: () => const UserRewardsSnapshot(),
  );
});

const int _pointsHistoryPageSize = 20;

final pointsHistoryProvider =
    StreamProvider.autoDispose<List<PointsEntry>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) return Stream.value(const []);

  return firestore
      .collection(TestMode.usersCollection)
      .doc(authUser.uid)
      .collection('pointsHistory')
      .orderBy('createdAt', descending: true)
      .limit(_pointsHistoryPageSize)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PointsEntry.fromJson(doc.data(), id: doc.id))
          .toList())
      .handleError((error, stackTrace) {
    AppLogger.error('Error loading pointsHistory',
        error: error, stackTrace: stackTrace);
    return <PointsEntry>[];
  });
});

final redeemableRewardsProvider =
    StreamProvider.autoDispose<List<Reward>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('rewards')
      .where('isActive', isEqualTo: true)
      .orderBy('pointsCost')
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Reward.fromJson(doc.data(), id: doc.id))
          .where((r) =>
              r.expiryDate == null || r.expiryDate!.isAfter(DateTime.now()))
          .toList())
      .handleError((error, stackTrace) {
    AppLogger.error('Error loading rewards',
        error: error, stackTrace: stackTrace);
    return <Reward>[];
  });
});

// ============================================
// PAGINATED BOOKING HISTORY PROVIDER
// ============================================

/// Provider for paginated booking history
final bookingHistoryProvider = StateNotifierProvider.family<
    BookingHistoryNotifier, PaginatedState<ActiveBooking>, String>(
  (ref, userId) => BookingHistoryNotifier(userId, ref),
);

/// Notifier for managing paginated booking history
class BookingHistoryNotifier extends PaginatedNotifier<ActiveBooking> {
  final String userId;
  final Ref ref;

  BookingHistoryNotifier(this.userId, this.ref)
      : super(config: const PaginationConfig(pageSize: 15)) {
    if (userId.isNotEmpty) {
      loadInitial();
    }
  }

  @override
  Query<Map<String, dynamic>> buildQuery(FirebaseFirestore firestore) {
    AppLogger.firestore('QUERY', 'bookings', docId: 'user: $userId');
    return firestore
        .collection(TestMode.bookingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);
  }

  @override
  ActiveBooking fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ActiveBooking.fromJson({...data, 'bookingId': doc.id});
  }
}

// ============================================
// ERROR-AWARE USER DATA PROVIDER
// ============================================

/// A more robust user data provider with proper error handling
final safeUserDashboardProvider = FutureProvider<Result<UserModel>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final authUser = ref.watch(currentUserProvider).value;

  if (authUser == null) {
    return Result.failure(AuthException.sessionExpired());
  }

  return runCatching(() async {
    AppLogger.firestore('GET', 'users', docId: authUser.uid);

    final doc = await firestore.collection(TestMode.usersCollection).doc(authUser.uid).get();

    if (doc.exists) {
      return UserModel.fromJson({
        ...doc.data()!,
        'userId': authUser.uid,
      });
    } else {
      // Return default user if document doesn't exist
      AppLogger.warning('User document not found, using defaults');
      return UserModel(
        userId: authUser.uid,
        userName: authUser.displayName ?? 'User',
        email: authUser.email,
        phoneNumber: authUser.phoneNumber,
      );
    }
  });
});
