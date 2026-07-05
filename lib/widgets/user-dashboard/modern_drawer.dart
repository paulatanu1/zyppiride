import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_dashboard_provider.dart';
import '../../router/routes_name.dart';

class ModernDrawer extends ConsumerWidget {
  final VoidCallback onClose;

  const ModernDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userDashboardProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: userState.when(
          data: (user) => Column(
            children: [
              _buildHeader(context, ref, user),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSection(context, ref, user, 'MENU', [
                      _ItemData(Icons.person_outline, 'My Profile', const Color(0xFF4F46E5), () {
                        onClose();
                        context.push('/user-profile');
                      }),
                      _ItemData(Icons.history, 'Ride History', const Color(0xFF0EA5E9), () {
                        onClose();
                        context.pushNamed(RoutesName.rideHistory, queryParameters: {'userId': user.userId});
                      }),
                      _ItemData(Icons.directions_car_outlined, 'Reserve Vehicle', const Color(0xFF10B981), () {
                        onClose();
                        context.push('/reserve-vehicle');
                      }),
                      _ItemData(Icons.card_giftcard_outlined, 'Offers & Rewards', const Color(0xFFF59E0B), () {
                        onClose();
                        context.pushNamed(RoutesName.offersRewards, queryParameters: {'userId': user.userId});
                      }),
                      _ItemData(Icons.notifications_outlined, 'Notifications', const Color(0xFFEF4444), () {
                        onClose();
                        context.pushNamed(RoutesName.notifications, queryParameters: {'userId': user.userId});
                      }, badge: user.notificationCount > 0 ? '${user.notificationCount}' : null),
                    ]),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    _buildSection(context, ref, user, 'SETTINGS', [
                      _ItemData(Icons.settings_outlined, 'Settings', const Color(0xFF6B7280), () { onClose(); }),
                      _ItemData(Icons.help_outline, 'Help & Support', const Color(0xFF8B5CF6), () {
                        onClose();
                        context.pushNamed(RoutesName.supportCenter, queryParameters: {'userId': user.userId});
                      }),
                      _ItemData(Icons.privacy_tip_outlined, 'Privacy Policy', const Color(0xFF6B7280), () {
                        onClose();
                        context.pushNamed(RoutesName.privacyPolicy);
                      }),
                    ]),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    _buildLogoutItem(context, ref),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
          error: (_, _) => const Center(
            child: Text('Error loading profile', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, dynamic user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF4F46E5),
        borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  onClose();
                  context.push('/user-profile');
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: ClipOval(
                    child: user.profileImageUrl != null
                        ? Image.network(
                            user.profileImageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const Icon(Icons.person, size: 30, color: Colors.white),
                          )
                        : const Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.userName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            user.email ?? user.phoneNumber ?? 'Zyppi User',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildStat(
                  user.totalRides == null ? '—' : '${user.totalRides}',
                  'Rides',
                ),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25)),
                _buildStat(
                  user.rating == null
                      ? '—'
                      : (user.rating as double).toStringAsFixed(1),
                  'Rating',
                ),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25)),
                _buildStat(_getMemberSince(user.createdAt), 'Member'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 15,
            fontWeight: FontWeight.bold, color: Colors.white,
          )),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
          )),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, WidgetRef ref, dynamic user, String title, List<_ItemData> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF), letterSpacing: 1.2,
              ),
            ),
          ),
          ...items.map((item) => _buildItem(item)),
        ],
      ),
    );
  }

  Widget _buildItem(_ItemData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(data.icon, size: 20, color: data.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 14,
                    fontWeight: FontWeight.w500, color: Color(0xFF111827),
                  ),
                ),
              ),
              if (data.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data.badge!,
                    style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 11,
                      fontWeight: FontWeight.bold, color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLogoutDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 14),
              const Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 14,
                  fontWeight: FontWeight.w600, color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car, color: Color(0xFF4F46E5), size: 16),
          const SizedBox(width: 6),
          const Text(
            'ZYPPI RIDE',
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 12,
              fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          const Text('v1.0.0', style: TextStyle(
            fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF9CA3AF),
          )),
        ],
      ),
    );
  }

  String _getMemberSince(dynamic createdAt) {
    if (createdAt == null) return '—';
    try {
      final DateTime date = createdAt is DateTime ? createdAt : createdAt.toDate();
      final months = DateTime.now().difference(date).inDays ~/ 30;
      if (months < 1) return 'New';
      if (months < 12) return '${months}m';
      return '${months ~/ 12}y';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        content: const Text(
          'Are you sure you want to log out from your account?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      onClose();
      await ref.read(firebaseAuthProvider).signOut();
      if (context.mounted) context.goNamed(RoutesName.login);
    }
  }
}

class _ItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _ItemData(this.icon, this.label, this.color, this.onTap, {this.badge});
}
