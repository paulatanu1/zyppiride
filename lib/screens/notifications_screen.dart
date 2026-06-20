import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

// ── Theme constants (mirrors user dashboard palette) ─────────────────────────
const Color _kBrand   = Color(0xFF4F46E5);
const Color _kBgLight = Color(0xFFF4F6FA);
const Color _kSurface = Colors.white;
const Color _kTextPri = Color(0xFF111827);
const Color _kTextSec = Color(0xFF6B7280);
const Color _kError   = Color(0xFFEF4444);
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  final String userId;

  const NotificationsScreen({super.key, required this.userId});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Rides', 'Offers', 'System'];

  List<NotificationItem> _applyFilter(List<NotificationItem> items) {
    if (_selectedFilter == 'All') return items;
    final type = _selectedFilter == 'Rides'
        ? 'ride'
        : _selectedFilter == 'Offers'
            ? 'offer'
            : 'system';
    return items.where((n) => n.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(userNotificationsProvider(widget.userId));

    return Scaffold(
      backgroundColor: _kBrand,
      body: Column(
        children: [
          // ── Purple header ────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/user-dashboard'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 20,
                        fontWeight: FontWeight.bold, color: Colors.white,
                      ),
                    ),
                  ),
                  notifAsync.when(
                    data: (items) {
                      final unread = items.where((n) => !n.isRead).toList();
                      if (unread.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () => markAllNotificationsRead(widget.userId, unread),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 12,
                              color: Colors.white, fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // ── White body ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kBgLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Filter tabs
                  _buildFilterTabs(),

                  // Notification list
                  Expanded(
                    child: notifAsync.when(
                      data: (items) {
                        final filtered = _applyFilter(items);
                        if (filtered.isEmpty) return _buildEmptyState();
                        return _buildList(filtered);
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: _kBrand),
                      ),
                      error: (e, _) => _buildErrorState(e.toString()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _kBrand : _kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _kBrand : const Color(0xFFE5E7EB),
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: _kBrand.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : _kTextSec,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<NotificationItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(items[index], index),
    );
  }

  Widget _buildCard(NotificationItem item, int index) {
    final typeInfo = _typeInfo(item.type);
    final color = typeInfo['color'] as Color;
    final icon  = typeInfo['icon'] as IconData;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _kError,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => deleteNotification(widget.userId, item.id),
      child: GestureDetector(
        onTap: () async {
          if (!item.isRead) {
            await markNotificationRead(widget.userId, item.id);
          }
          if (item.actionRoute != null && mounted) {
            context.push(item.actionRoute!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: !item.isRead
                ? Border(left: BorderSide(color: color, width: 4))
                : Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: _kTextPri,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: _kTextSec,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined, size: 48, color: _kBrand),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 17,
              fontWeight: FontWeight.bold, color: _kTextPri,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'re all caught up!',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kTextSec),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _kError),
          const SizedBox(height: 12),
          const Text(
            'Unable to load notifications',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 15, color: _kTextPri),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _typeInfo(String type) {
    switch (type) {
      case 'ride':
        return {'icon': Icons.directions_car_outlined, 'color': _kBrand};
      case 'offer':
        return {'icon': Icons.local_offer_outlined, 'color': const Color(0xFFF59E0B)};
      default:
        return {'icon': Icons.info_outline, 'color': _kTextSec};
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
