import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../models/active_booking_model.dart';
import '../../models/offer_model.dart';
import '../../providers/user_dashboard_provider.dart';
import '../../router/routes_name.dart';
import '../../widgets/quick_action_button.dart';
import '../../widgets/offer_banner_slider.dart';
import '../../widgets/user-dashboard/modern_drawer.dart';
import '../../widgets/user-dashboard/location_bar.dart';

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});

  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrHasBeenPressedLongTimeAgo =
        _lastPressedAt == null ||
        now.difference(_lastPressedAt!) > const Duration(seconds: 2);

    if (backButtonHasNotBeenPressedOrHasBeenPressedLongTimeAgo) {
      _lastPressedAt = now;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Press back again to exit',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.black26,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userDashboardProvider);
    final activeBooking = ref.watch(activeBookingProvider);
    final offers = ref.watch(offersProvider);
    final offerBanners = ref.watch(offerBannersProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: userState.when(
            data: (user) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  'Hi, ${user.userName} 👋',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            loading: () => const SizedBox(),
            error: (e, st) => const SizedBox(),
          ),
          actions: [
            userState.maybeWhen(
              data: (user) => Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 28),
                    color: Colors.white,
                    onPressed: () {
                      context.goNamed(
                        RoutesName.notifications,
                        queryParameters: {'userId': user.userId},
                      );
                    },
                  ),
                  if (user.notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${user.notificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              orElse: () => const SizedBox(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: const ModernDrawer(),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade700,
                Colors.deepPurple.shade500,
                Colors.deepPurple.shade300,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // Invalidate all providers to refresh data
                ref.invalidate(userDashboardProvider);
                ref.invalidate(activeBookingProvider);
                ref.invalidate(offersProvider);
                ref.invalidate(offerBannersProvider);
              },
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Location Bar Section
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 8),
                          child: LocationBar(),
                        ),
                      ),

                      // Offer Banner Section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 24),
                          child: offerBanners.when(
                            data: (offerBannerList) => OfferBannerSlider(
                              offerBanners: offerBannerList,
                              onBannerTap: (banner) {
                                if (banner.actionRoute != null) {
                                  userState.whenData((user) {
                                    context.goNamed(
                                      banner.actionRoute!,
                                      queryParameters: {'userId': user.userId},
                                    );
                                  });
                                }
                              },
                            ),
                            loading: () => const SizedBox(
                              height: 220,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            error: (error, _) => const SizedBox(),
                          ),
                        ),
                      ),

                      // Quick Actions Section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Actions',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              userState.when(
                                data: (user) => _buildQuickActions(user.userId),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                                error: (e, st) => const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),

                      // Active Booking Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: activeBooking.when(
                            data: (booking) => booking != null
                                ? _buildActiveBookingCard(booking)
                                : _buildNoBookingCard(),
                            loading: () => _buildLoadingBookingCard(),
                            error: (e, st) => const SizedBox(),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),

                      // Service Categories
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Our Services',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              userState.when(
                                data: (user) =>
                                    _buildServiceCategories(user.userId),
                                loading: () => const SizedBox(),
                                error: (e, st) => const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),

                      // Offers & Rewards
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Text(
                                'Offers & Rewards',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            offers.when(
                              data: (offerList) => SizedBox(
                                height: 185,
                                child: offerList.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No offers available',
                                          style: TextStyle(fontFamily: 'Poppins', 
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        itemCount: offerList.length,
                                        itemBuilder: (context, index) {
                                          final offer = offerList[index];
                                          return _buildOfferCard(offer);
                                        },
                                      ),
                              ),
                              loading: () => const SizedBox(
                                height: 185,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              error: (error, _) => const SizedBox(),
                            ),
                          ],
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),

                      // Why Choose Us
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Why Choose Us',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildWhyChooseUs(),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildQuickActions(String userId) {
    final actions = [
      {
        'icon': Icons.directions_car_outlined,
        'label': 'Reserve\nVehicle',
        'route': RoutesName.reserveVehicle,
        'gradientStart': const Color(0xFF6A11CB),
        'gradientEnd': const Color(0xFF2575FC),
      },
      {
        'icon': Icons.local_shipping_outlined,
        'label': 'Book Goods\nCarrier',
        'route': RoutesName.bookGoodsCarrier,
        'gradientStart': const Color(0xFFFF6B6B),
        'gradientEnd': const Color(0xFFEE5A6F),
      },
      {
        'icon': Icons.location_on_outlined,
        'label': 'Track\nBooking',
        'route': RoutesName.trackActiveBooking,
        'gradientStart': const Color(0xFF00D2FF),
        'gradientEnd': const Color(0xFF3A7BD5),
      },
      {
        'icon': Icons.history,
        'label': 'Ride\nHistory',
        'route': RoutesName.rideHistory,
        'gradientStart': const Color(0xFFF093FB),
        'gradientEnd': const Color(0xFFF5576C),
      },
      {
        'icon': Icons.support_agent,
        'label': 'Support\nCenter',
        'route': RoutesName.supportCenter,
        'gradientStart': const Color(0xFF4FACFE),
        'gradientEnd': const Color(0xFF00F2FE),
      },
      {
        'icon': Icons.card_giftcard,
        'label': 'Offers &\nRewards',
        'route': RoutesName.offersRewards,
        'gradientStart': const Color(0xFFFFD194),
        'gradientEnd': const Color(0xFFFF6F91),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return QuickActionButton(
          icon: action['icon'] as IconData,
          label: action['label'] as String,
          gradientStart: action['gradientStart'] as Color,
          gradientEnd: action['gradientEnd'] as Color,
          onTap: () {
            context.goNamed(
              action['route'] as String,
              queryParameters: {'userId': userId},
            );
          },
        );
      },
    );
  }

  Widget _buildActiveBookingCard(ActiveBooking booking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Booking',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          booking.vehicleType,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      booking.status,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          booking.driverName,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ETA',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        booking.eta,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.goNamed(RoutesName.trackActiveBooking);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Track Live Location',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoBookingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            'No Active Bookings',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book a ride to get started',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.goNamed(RoutesName.reserveVehicle);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Book Now',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBookingCard() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildServiceCategories(String userId) {
    final services = [
      {
        'icon': Icons.local_taxi,
        'title': 'Local Transport',
        'desc': 'Quick city rides',
        'route': RoutesName.localTransport,
      },
      {
        'icon': Icons.route,
        'title': 'Outstation Rental',
        'desc': 'Long distance travel',
        'route': RoutesName.outstationRental,
      },
      {
        'icon': Icons.inventory_2_outlined,
        'title': 'Goods Transport',
        'desc': 'Safe cargo delivery',
        'route': RoutesName.goodsTransport,
      },
      {
        'icon': Icons.fire_truck,
        'title': 'Mini Truck',
        'desc': 'Heavy load moving',
        'route': RoutesName.miniTruckDelivery,
      },
      {
        'icon': Icons.two_wheeler,
        'title': 'Bike Parcel',
        'desc': 'Quick deliveries',
        'route': RoutesName.bikeParcel,
      },
      {
        'icon': Icons.emergency,
        'title': 'Emergency',
        'desc': '24/7 emergency service',
        'route': RoutesName.emergency,
      },
    ];

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return GestureDetector(
            onTap: () {
              context.goNamed(
                service['route'] as String,
                queryParameters: {'userId': userId},
              );
            },
            child: Container(
              width: 145,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      service['icon'] as IconData,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          service['title'] as String,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service['desc'] as String,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(OfferData offer) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD194), Color(0xFFFF6F91)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6F91).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    offer.discount,
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6F91),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.local_offer, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  offer.title,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  offer.description,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    'Code: ${offer.code}',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseUs() {
    final features = [
      {'icon': Icons.verified_user, 'title': 'Verified\nDrivers'},
      {'icon': Icons.support_agent, 'title': '24×7\nSupport'},
      {'icon': Icons.gps_fixed, 'title': 'Live\nTracking'},
      {'icon': Icons.shield, 'title': 'Safe &\nInsured'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  feature['icon'] as IconData,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  feature['title'] as String,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
