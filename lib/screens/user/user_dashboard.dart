import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/active_booking_model.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_dashboard_provider.dart';
import '../../router/routes_name.dart';
import '../../widgets/quick_action_button.dart';
import '../../widgets/offer_banner_slider.dart';
import '../../widgets/user-dashboard/modern_drawer.dart';
import '../../widgets/user-dashboard/location_bar.dart';
import '../../main.dart' show scaffoldMessengerKey;
import '../../providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Brand palette (no gradients) ──────────────────────────────────────────────
const Color _kBrand     = Color(0xFF4F46E5);
const Color _kBrandDark = Color(0xFF1E1B4B);
const Color _kBgLight   = Color(0xFFF4F6FA);
const Color _kSurface   = Colors.white;
const Color _kTextPri   = Color(0xFF111827);
const Color _kTextSec   = Color(0xFF6B7280);
const Color _kSuccess   = Color(0xFF10B981);
const Color _kWarning   = Color(0xFFF59E0B);
const Color _kError     = Color(0xFFEF4444);
// ──────────────────────────────────────────────────────────────────────────────

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});

  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard>
    with TickerProviderStateMixin {

  late AnimationController _drawerController;
  late AnimationController _pageController;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();

    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pageFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _pageController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        ref.read(notificationProvider.notifier).subscribeAsUser(uid);
      }
    });
  }

  @override
  void dispose() {
    _drawerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openDrawer()  => _drawerController.animateTo(1.0, curve: Curves.easeInOutCubic);
  void _closeDrawer() => _drawerController.animateTo(0.0, curve: Curves.easeInOutCubic);

  Future<bool> _onWillPop() async {
    if (_drawerController.value > 0.1) {
      _closeDrawer();
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      if (mounted) {
        scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
                SizedBox(width: 10),
                Text('Press back again to exit',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: _kTextPri,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.78;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: _kBrandDark,
        body: AnimatedBuilder(
          animation: _drawerController,
          // child is evaluated once per build() — ref.watch() is safe here
          child: _buildMainScaffold(),
          builder: (ctx, child) {
            final t = _drawerController.value;
            return Stack(
              children: [
                // ── Main content — never moved or scaled ─────────────────
                child!,

                // ── Dark scrim overlay when drawer is open ────────────────
                if (t > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: t < 0.01,
                      child: GestureDetector(
                        onTap: _closeDrawer,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55 * t),
                        ),
                      ),
                    ),
                  ),

                // ── Drawer panel slides in from left ──────────────────────
                Positioned(
                  left: drawerWidth * (t - 1.0),
                  top: 0,
                  bottom: 0,
                  width: drawerWidth,
                  child: ModernDrawer(onClose: _closeDrawer),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Main scaffold — called as AnimatedBuilder.child (build phase only) ────
  // NOTE: AsyncValue.when is an extension method, resolved at compile time.
  // Never pass AsyncValue<T> as a dynamic/untyped param — always call .when()
  // here where the static type is known, then pass the extracted value.
  Widget _buildMainScaffold() {
    final userState    = ref.watch(userDashboardProvider);
    final activeBooking = ref.watch(activeBookingProvider);
    final offers       = ref.watch(offersProvider);
    final offerBanners = ref.watch(offerBannersProvider);

    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: Container(
          color: _kBrand,
          child: Column(
            children: [
              // ── Purple header ──────────────────────────────────────────
              userState.when(
                data: (user) => _buildHeader(user),
                loading: () => _buildHeaderSkeleton(),
                error: (_, _) => _buildHeaderSkeleton(),
              ),

              // ── White body (rounded top) ───────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: _kBgLight,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(userDashboardProvider);
                      ref.invalidate(activeBookingProvider);
                      ref.invalidate(offersProvider);
                      ref.invalidate(offerBannersProvider);
                    },
                    color: _kBrand,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [

                        // Offer banners
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 4),
                            child: offerBanners.when(
                              data: (list) => list.isEmpty
                                  ? const SizedBox()
                                  : OfferBannerSlider(
                                      offerBanners: list,
                                      onBannerTap: (banner) {
                                        if (banner.actionRoute != null) {
                                          userState.whenData((user) {
                                            context.pushNamed(
                                              banner.actionRoute!,
                                              queryParameters: {'userId': user.userId},
                                            );
                                          });
                                        }
                                      },
                                    ),
                              loading: () => const SizedBox(
                                height: 180,
                                child: Center(child: CircularProgressIndicator(color: _kBrand)),
                              ),
                              error: (_, _) => const SizedBox(),
                            ),
                          ),
                        ),

                        // Quick Actions
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Quick Actions',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                                        fontWeight: FontWeight.bold, color: _kTextPri)),
                                const SizedBox(height: 16),
                                userState.when(
                                  data: (user) => _buildQuickActions(user.userId),
                                  loading: () => const Center(child: CircularProgressIndicator(color: _kBrand)),
                                  error: (_, _) => const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Active Booking
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                            child: activeBooking.when(
                              data: (booking) => booking != null
                                  ? _buildActiveBookingCard(booking)
                                  : _buildNoBookingCard(),
                              loading: () => _buildLoadingCard(),
                              error: (_, _) => const SizedBox(),
                            ),
                          ),
                        ),

                        // Our Services
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Our Services',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                                        fontWeight: FontWeight.bold, color: _kTextPri)),
                                const SizedBox(height: 16),
                                userState.when(
                                  data: (user) => _buildServiceGrid(user.userId),
                                  loading: () => const SizedBox(),
                                  error: (_, _) => const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Offers & Rewards
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Text('Offers & Rewards',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                                          fontWeight: FontWeight.bold, color: _kTextPri)),
                                ),
                                const SizedBox(height: 16),
                                offers.when(
                                  data: (list) => list.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20),
                                          child: Text('No offers available',
                                              style: TextStyle(fontFamily: 'Poppins', color: _kTextSec)),
                                        )
                                      : SizedBox(
                                          height: 170,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            itemCount: list.length,
                                            itemBuilder: (_, i) => _buildOfferCard(list[i]),
                                          ),
                                        ),
                                  loading: () => const SizedBox(
                                    height: 170,
                                    child: Center(child: CircularProgressIndicator(color: _kBrand)),
                                  ),
                                  error: (_, _) => const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Why Choose Us
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 44),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Why Choose Us',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                                        fontWeight: FontWeight.bold, color: _kTextPri)),
                                const SizedBox(height: 16),
                                _buildWhyChooseUs(),
                              ],
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Purple header with user data ──────────────────────────────────────────
  Widget _buildHeader(UserModel user) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _openDrawer,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        'Hi, ${user.userName} 👋',
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 17,
                          color: Colors.white, fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.pushNamed(
                    RoutesName.notifications,
                    queryParameters: {'userId': user.userId},
                  ),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      ),
                      if (user.notificationCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _kError,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LocationBar(),
          ],
        ),
      ),
    );
  }

  // ── Header skeleton (loading / error state) ───────────────────────────────
  Widget _buildHeaderSkeleton() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _openDrawer,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const Expanded(child: SizedBox()),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LocationBar(),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── Quick Actions 3×2 grid ────────────────────────────────────────────────
  Widget _buildQuickActions(String userId) {
    final actions = [
      {'icon': Icons.directions_car_outlined, 'label': 'Reserve\nVehicle',    'route': RoutesName.reserveVehicle,    'color': _kBrand},
      {'icon': Icons.local_shipping_outlined, 'label': 'Book Goods\nCarrier', 'route': RoutesName.bookGoodsCarrier,  'color': _kError},
      {'icon': Icons.location_on_outlined,    'label': 'Track\nBooking',      'route': RoutesName.trackActiveBooking,'color': const Color(0xFF0EA5E9)},
      {'icon': Icons.history,                 'label': 'Ride\nHistory',       'route': RoutesName.rideHistory,       'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.support_agent,           'label': 'Support\nCenter',     'route': RoutesName.supportCenter,     'color': _kSuccess},
      {'icon': Icons.card_giftcard,           'label': 'Offers &\nRewards',   'route': RoutesName.offersRewards,     'color': _kWarning},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final a = actions[i];
        return QuickActionButton(
          icon: a['icon'] as IconData,
          label: a['label'] as String,
          iconColor: a['color'] as Color,
          onTap: () => context.pushNamed(
            a['route'] as String,
            queryParameters: {'userId': userId},
          ),
        );
      },
    );
  }

  // ── Active booking card ───────────────────────────────────────────────────
  Widget _buildActiveBookingCard(ActiveBooking booking) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: _kSuccess,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kSuccess.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_shipping, color: _kSuccess, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Booking',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kTextSec)),
                          Text(booking.vehicleType,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 17,
                                  fontWeight: FontWeight.bold, color: _kTextPri),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kWarning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(booking.status,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                              fontWeight: FontWeight.w600, color: _kWarning)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const CircleAvatar(radius: 20, backgroundColor: _kBgLight,
                        child: Icon(Icons.person, color: _kTextSec, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driver',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kTextSec)),
                          Text(booking.driverName,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15,
                                  fontWeight: FontWeight.w600, color: _kTextPri),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('ETA',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kTextSec)),
                        Text(booking.eta,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18,
                                fontWeight: FontWeight.bold, color: _kBrand)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pushNamed(RoutesName.trackActiveBooking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Track Live Location',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBookingCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car_outlined, size: 40, color: _kBrand),
          ),
          const SizedBox(height: 16),
          const Text('No Active Booking',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.bold, color: _kTextPri)),
          const SizedBox(height: 6),
          const Text('Book a ride to get started',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kTextSec)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pushNamed(RoutesName.reserveVehicle),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Book Now',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: const Center(child: CircularProgressIndicator(color: _kBrand)),
    );
  }

  // ── Services 2-column grid ────────────────────────────────────────────────
  Widget _buildServiceGrid(String userId) {
    final services = [
      {'icon': Icons.local_taxi,           'title': 'Local Transport', 'desc': 'Quick city rides',     'route': RoutesName.localTransport,    'color': _kBrand},
      {'icon': Icons.route,                'title': 'Outstation',      'desc': 'Long distance travel',  'route': RoutesName.outstationRental,  'color': const Color(0xFF0EA5E9)},
      {'icon': Icons.inventory_2_outlined, 'title': 'Goods Transport', 'desc': 'Safe cargo delivery',  'route': RoutesName.goodsTransport,    'color': _kWarning},
      {'icon': Icons.fire_truck,           'title': 'Mini Truck',      'desc': 'Heavy load moving',     'route': RoutesName.miniTruckDelivery, 'color': _kError},
      {'icon': Icons.two_wheeler,          'title': 'Bike Parcel',     'desc': 'Quick deliveries',      'route': RoutesName.bikeParcel,        'color': _kSuccess},
      {'icon': Icons.emergency,            'title': 'Emergency',       'desc': '24/7 emergency',        'route': RoutesName.emergency,         'color': _kError},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: services.length,
      itemBuilder: (context, i) {
        final s = services[i];
        final color = s['color'] as Color;
        return InkWell(
          onTap: () => context.pushNamed(
            s['route'] as String,
            queryParameters: {'userId': userId},
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s['title'] as String,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                              fontWeight: FontWeight.bold, color: _kTextPri),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(s['desc'] as String,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kTextSec),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Offer card ────────────────────────────────────────────────────────────
  Widget _buildOfferCard(OfferData offer) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border(top: BorderSide(color: _kBrand.withValues(alpha: 0.35), width: 3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(8)),
                child: Text(offer.discount,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                        fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              const Icon(Icons.local_offer, color: _kBrand, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.bold, color: _kTextPri),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(offer.description,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kTextSec),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBrand.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kBrand.withValues(alpha: 0.18)),
                ),
                child: Text('Code: ${offer.code}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                        fontWeight: FontWeight.bold, color: _kBrand, letterSpacing: 0.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Why Choose Us ─────────────────────────────────────────────────────────
  Widget _buildWhyChooseUs() {
    const features = [
      {'icon': Icons.verified_user, 'title': 'Verified\nDrivers', 'color': _kBrand},
      {'icon': Icons.support_agent, 'title': '24×7\nSupport',     'color': _kSuccess},
      {'icon': Icons.gps_fixed,     'title': 'Live\nTracking',    'color': Color(0xFF0EA5E9)},
      {'icon': Icons.shield,        'title': 'Safe &\nInsured',   'color': _kWarning},
    ];

    return Row(
      children: features.map((f) {
        final color = f['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(f['icon'] as IconData, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  f['title'] as String,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 9,
                      fontWeight: FontWeight.w600, color: _kTextPri, height: 1.3),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
