
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zyppi_ride/router/routes_name.dart';

// User State Model
class UserState {
  final String userId;
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  final int notificationCount;
  final bool hasActiveBooking;

  UserState({
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    this.notificationCount = 0,
    this.hasActiveBooking = false,
  });

  UserState copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? profileImageUrl,
    int? notificationCount,
    bool? hasActiveBooking,
  }) {
    return UserState(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      notificationCount: notificationCount ?? this.notificationCount,
      hasActiveBooking: hasActiveBooking ?? this.hasActiveBooking,
    );
  }
}

// Active Booking Model
class ActiveBooking {
  final String bookingId;
  final String vehicleType;
  final String driverName;
  final String status;
  final String eta;
  final String? driverPhone;

  ActiveBooking({
    required this.bookingId,
    required this.vehicleType,
    required this.driverName,
    required this.status,
    required this.eta,
    this.driverPhone,
  });
}

// User Dashboard State Notifier
class UserDashboardNotifier extends StateNotifier<AsyncValue<UserState>> {
  UserDashboardNotifier() : super(const AsyncValue.loading()) {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Simulated data - replace with actual Firestore fetch
        await Future.delayed(const Duration(milliseconds: 800));
        
        state = AsyncValue.data(UserState(
          userId: user.uid,
          userName: user.displayName ?? 'User',
          userEmail: user.email ?? '',
          profileImageUrl: user.photoURL,
          notificationCount: 3,
          hasActiveBooking: false,
        ));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void updateNotificationCount(int count) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(notificationCount: count));
    });
  }

  Future<void> refreshUserData() async {
    await _loadUserData();
  }
}

// Provider
final userDashboardProvider =
    StateNotifierProvider<UserDashboardNotifier, AsyncValue<UserState>>((ref) {
  return UserDashboardNotifier();
});

// Active Booking Provider
final activeBookingProvider = FutureProvider<ActiveBooking?>((ref) async {
  // Simulated fetch - replace with Firestore query
  await Future.delayed(const Duration(milliseconds: 600));
  
  // Return null if no active booking
  return null;
  
  // Example active booking:
  // return ActiveBooking(
  //   bookingId: 'BK123456',
  //   vehicleType: 'Mini Truck',
  //   driverName: 'Rajesh Kumar',
  //   status: 'On the way',
  //   eta: '10 mins',
  //   driverPhone: '+91 98765 43210',
  // );
});

// Banner Data Provider
class BannerData {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? actionRoute;

  BannerData({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.actionRoute,
  });
}

final bannerDataProvider = Provider<List<BannerData>>((ref) {
  return [
    BannerData(
      imageUrl: 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=800',
      title: 'Book Your Ride Today',
      subtitle: 'Get 20% off on first booking',
      actionRoute: RoutesName.reserveVehicle,
    ),
    BannerData(
      imageUrl: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800',
      title: 'Goods Transportation',
      subtitle: 'Safe & Secure Delivery',
      actionRoute: RoutesName.goodsTransport,
    ),
    BannerData(
      imageUrl: 'https://images.unsplash.com/photo-1519003722824-194d4455a60c?w=800',
      title: '24/7 Support Available',
      subtitle: 'We are here to help you',
      actionRoute: RoutesName.supportCenter,
    ),
  ];
});

// Offers Provider
class OfferData {
  final String title;
  final String description;
  final String discount;
  final String code;

  OfferData({
    required this.title,
    required this.description,
    required this.discount,
    required this.code,
  });
}

final offersProvider = Provider<List<OfferData>>((ref) {
  return [
    OfferData(
      title: 'First Ride Free',
      description: 'Book your first ride and get free delivery',
      discount: '100% OFF',
      code: 'FIRST100',
    ),
    OfferData(
      title: 'Weekend Special',
      description: 'Extra 15% off on weekend bookings',
      discount: '15% OFF',
      code: 'WEEKEND15',
    ),
    OfferData(
      title: 'Refer & Earn',
      description: 'Invite friends and earn rewards',
      discount: '₹200',
      code: 'REFER200',
    ),
  ];
});
