import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/active_booking_model.dart';
import '../models/banner_model.dart';
import '../models/offer_model.dart';
import '../models/offer_banner_model.dart';

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
      .collection('users')
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
      final doc = await firestore.collection('users').doc(authUser.uid).get();
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

  // Query active bookings for current user
  return firestore
      .collection('bookings')
      .where('userId', isEqualTo: authUser.uid)
      .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return ActiveBooking.fromJson(snapshot.docs.first.data());
  });
});

// ============================================
// BANNER DATA PROVIDER
// ============================================
final bannerDataProvider = StreamProvider<List<BannerData>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('banners')
      .where('isActive', isEqualTo: true)
      .orderBy('priority', descending: true)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return _getMockBanners();
    }
    return snapshot.docs.map((doc) => BannerData.fromJson(doc.data())).toList();
  }).handleError((error) {
    // Return mock data on permission or other errors
    return _getMockBanners();
  });
});

// Mock banners for testing
List<BannerData> _getMockBanners() {
  return [
    BannerData(
      imageUrl: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800',
      title: 'Book Your Ride',
      subtitle: 'Safe & comfortable travel',
      actionRoute: 'reserveVehicle',
    ),
    BannerData(
      imageUrl: 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=800',
      title: 'Premium Vehicles',
      subtitle: 'Travel in style',
      actionRoute: 'reserveVehicle',
    ),
  ];
}

// ============================================
// OFFERS PROVIDER
// ============================================
final offersProvider = StreamProvider<List<OfferData>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('offers')
      .where('isActive', isEqualTo: true)
      .where('expiryDate', isGreaterThan: Timestamp.now())
      .orderBy('expiryDate')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return _getMockOffers();
    }
    return snapshot.docs.map((doc) => OfferData.fromJson(doc.data())).toList();
  }).handleError((error) {
    // Return mock data on permission or other errors
    return _getMockOffers();
  });
});

// Mock offers for testing
List<OfferData> _getMockOffers() {
  return [
    OfferData(
      discount: '50% OFF',
      title: 'First Ride Free',
      description: 'Get 50% off on your first ride',
      code: 'FIRST50',
    ),
    OfferData(
      discount: '20% OFF',
      title: 'Weekend Special',
      description: 'Book rides on weekends',
      code: 'WEEKEND20',
    ),
    OfferData(
      discount: '30% OFF',
      title: 'Refer & Earn',
      description: 'Get 30% off when you refer a friend',
      code: 'REFER30',
    ),
  ];
}

// ============================================
// OFFER BANNERS PROVIDER
// ============================================
final offerBannersProvider = StreamProvider<List<OfferBannerData>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('offer_banners')
      .where('isActive', isEqualTo: true)
      .orderBy('priority', descending: true)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return _getMockOfferBanners();
    }
    return snapshot.docs
        .map((doc) => OfferBannerData.fromJson(doc.data(), docId: doc.id))
        .where((banner) =>
            banner.expiryDate == null ||
            banner.expiryDate!.isAfter(DateTime.now()))
        .toList();
  }).handleError((error) {
    // Return mock data on permission or other errors
    return _getMockOfferBanners();
  });
});

// Mock offer banners for testing
List<OfferBannerData> _getMockOfferBanners() {
  return [
    OfferBannerData(
      id: '1',
      imageUrl: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800',
      title: 'First Ride Bonus',
      subtitle: 'Get amazing discount on your first ride with us',
      discount: '50% OFF',
      promoCode: 'FIRST50',
      priority: 3,
    ),
    OfferBannerData(
      id: '2',
      imageUrl: 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=800',
      title: 'Weekend Special',
      subtitle: 'Book any ride this weekend and save big',
      discount: '30% OFF',
      promoCode: 'WEEKEND30',
      priority: 2,
    ),
    OfferBannerData(
      id: '3',
      imageUrl: 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=800',
      title: 'Refer & Earn',
      subtitle: 'Invite friends and earn rewards on every referral',
      discount: 'Up to ₹500',
      promoCode: 'REFER500',
      priority: 1,
    ),
  ];
}
