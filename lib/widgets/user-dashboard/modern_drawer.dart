import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../providers/user_dashboard_provider.dart';
import '../../router/routes_name.dart';

class ModernDrawer extends ConsumerStatefulWidget {
  const ModernDrawer({super.key});

  @override
  ConsumerState<ModernDrawer> createState() => _ModernDrawerState();
}

class _ModernDrawerState extends ConsumerState<ModernDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userDashboardProvider);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade800,
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade400,
            ],
          ),
        ),
        child: userState.when(
          data: (user) => ScaleTransition(
            scale: _scaleAnimation,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerHeader(context, user),
                    _buildMenuSection(context, user),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Divider(color: Colors.white24, thickness: 1),
                    ),
                    _buildSettingsSection(context, user),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Divider(color: Colors.white24, thickness: 1),
                    ),
                    _buildLogoutSection(context),
                    const SizedBox(height: 20),
                    _buildAppVersion(),
                  ],
                ),
              ),
            ),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading profile',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, user) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/user-profile');
                },
                child: Hero(
                  tag: 'profile-avatar-drawer',
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage: user.profileImageUrl != null
                          ? NetworkImage(user.profileImageUrl!)
                          : null,
                      child: user.profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.deepPurple.shade700,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.userName,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? user.phoneNumber ?? 'Zyppi User',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
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
          const SizedBox(height: 16),
          // User Stats Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  icon: Icons.directions_car,
                  value: '${user.totalRides ?? 0}',
                  label: 'Rides',
                ),
                Container(
                  height: 35,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                _buildStatColumn(
                  icon: Icons.star,
                  value: '${(user.rating ?? 5.0).toStringAsFixed(1)}',
                  label: 'Rating',
                ),
                Container(
                  height: 35,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                _buildStatColumn(
                  icon: Icons.calendar_today,
                  value: _getMemberSince(user.createdAt),
                  label: 'Member',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            'MENU',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.person_outline,
          title: 'My Profile',
          subtitle: 'View and edit profile',
          onTap: () {
            Navigator.pop(context);
            context.push('/user-profile');
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.history,
          title: 'Ride History',
          subtitle: 'View past bookings',
          onTap: () {
            Navigator.pop(context);
            context.pushNamed(
              RoutesName.rideHistory,
              queryParameters: {'userId': user.userId},
            );
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.directions_car_outlined,
          title: 'Reserve Vehicle',
          subtitle: 'Book a ride',
          onTap: () {
            Navigator.pop(context);
            context.push('/reserve-vehicle');
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.card_giftcard_outlined,
          title: 'Offers & Rewards',
          subtitle: 'View all offers',
          badge: '3',
          onTap: () {
            Navigator.pop(context);
            context.pushNamed(
              RoutesName.offersRewards,
              queryParameters: {'userId': user.userId},
            );
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notifications',
          badge: user.notificationCount > 0
              ? '${user.notificationCount}'
              : null,
          onTap: () {
            Navigator.pop(context);
            context.pushNamed(
              RoutesName.notifications,
              queryParameters: {'userId': user.userId},
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Text(
            'SETTINGS',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'App preferences',
          onTap: () {
            Navigator.pop(context);
            // context.goNamed(
            //   RoutesName.settings,
            //   queryParameters: {'userId': user.userId},
            // );
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help',
          onTap: () {
            Navigator.pop(context);
            context.pushNamed(
              RoutesName.supportCenter,
              queryParameters: {'userId': user.userId},
            );
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'About Zyppi Ride',
          onTap: () {
            Navigator.pop(context);
            // context.goNamed(RoutesName.about);
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'Terms & conditions',
          onTap: () {
            Navigator.pop(context);
            // context.goNamed(RoutesName.privacyPolicy);
          },
        ),
      ],
    );
  }

  Widget _buildLogoutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLogoutDialog(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.2),
                  Colors.red.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logout',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade300,
                        ),
                      ),
                      Text(
                        'Sign out from your account',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.red.shade200.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.red.shade300,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 14,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  String _getMemberSince(dynamic createdAt) {
    if (createdAt == null) return 'New';
    try {
      DateTime date;
      if (createdAt is DateTime) {
        date = createdAt;
      } else {
        // Assume Timestamp from Firestore
        date = createdAt.toDate();
      }
      final months = DateTime.now().difference(date).inDays ~/ 30;
      if (months < 1) return 'New';
      if (months < 12) return '${months}m';
      return '${months ~/ 12}y';
    } catch (_) {
      return 'New';
    }
  }

  Widget _buildAppVersion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ZYPPI RIDE',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Version 1.0.0',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Logout',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to logout from your account?',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true && context.mounted) {
      Navigator.pop(context); // Close drawer
      // Sign out from Firebase - this will trigger providers to switch to unauthenticated state
      await ref.read(firebaseAuthProvider).signOut();
      if (context.mounted) {
        context.goNamed(RoutesName.login);
      }
    }
  }
}
