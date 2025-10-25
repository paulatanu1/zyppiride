import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardTiles extends StatelessWidget {
  final String userId;
  final String role;

  const DashboardTiles({super.key, required this.userId, required this.role});

  static final List<Map<String, dynamic>> _tiles = [
    {
      'title': 'Vehicle Registration',
      'icon': Icons.directions_car,
      'gradient': const LinearGradient(
        colors: [Colors.blue, Colors.blueAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/vehicle-list',
    },
    {
      'title': 'Document Upload',
      'icon': Icons.upload_file,
      'gradient': const LinearGradient(
        colors: [Colors.green, Colors.greenAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/document-upload',
    },
    {
      'title': 'Agreement Signing',
      'icon': Icons.description,
      'gradient': const LinearGradient(
        colors: [Colors.purple, Colors.purpleAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/agreement-signing',
    },
    {
      'title': 'Ride History',
      'icon': Icons.history,
      'gradient': const LinearGradient(
        colors: [Colors.orange, Colors.deepOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/ride-history',
    },
    {
      'title': 'Notifications',
      'icon': Icons.notifications,
      'gradient': const LinearGradient(
        colors: [Colors.red, Colors.redAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/notifications',
    },
    {
      'title': 'Active Vehicles',
      'icon': Icons.car_rental,
      'gradient': const LinearGradient(
        colors: [Colors.teal, Colors.tealAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/active-vehicles',
    },
    {
      'title': 'Delivery Requests',
      'icon': Icons.local_shipping,
      'gradient': const LinearGradient(
        colors: [Colors.indigo, Colors.indigoAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/delivery-requests',
    },
    {
      'title': 'Support Center',
      'icon': Icons.support_agent,
      'gradient': const LinearGradient(
        colors: [Colors.cyan, Colors.cyanAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/support-center',
    },
    {
      'title': 'Availability',
      'icon': Icons.schedule,
      'gradient': const LinearGradient(
        colors: [Colors.amber, Colors.amberAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/availability',
    },
    {
      'title': 'Promotions',
      'icon': Icons.local_offer,
      'gradient': const LinearGradient(
        colors: [Colors.pink, Colors.pinkAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'route': '/promotions',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (role != 'Vehicle Owner' && role != 'Driver') {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(5.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _tiles.length,
      itemBuilder: (context, index) {
        final tile = _tiles[index];
        return ModernTileCard(
          tile: tile,
          userId: userId,
          index: index,
        );
      },
    );
  }
}

class ModernTileCard extends StatefulWidget {
  final Map<String, dynamic> tile;
  final String userId;
  final int index;

  const ModernTileCard({
    super.key,
    required this.tile,
    required this.userId,
    required this.index,
  });

  @override
  State<ModernTileCard> createState() => _ModernTileCardState();
}

class _ModernTileCardState extends State<ModernTileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          FirebaseAnalytics.instance.logEvent(
            name: 'tile_tapped',
            parameters: {'tile': widget.tile['title'], 'userId': widget.userId},
          );
          context.go('${widget.tile['route']}?userId=${widget.userId}');
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (widget.tile['gradient'] as LinearGradient)
                      .colors
                      .first
                      .withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Base gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: widget.tile['gradient'],
                    ),
                  ),
                  // Animated gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Large decorative circle top-right
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Small decorative circle bottom-left
                  Positioned(
                    bottom: -25,
                    left: -25,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Floating dots pattern
                  Positioned(
                    top: 20,
                    left: 15,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    right: 20,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: 15,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  // Main content - perfectly centered
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icon container with glass effect
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.tile['icon'],
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            widget.tile['title'],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              height: 1.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Subtle shine effect on top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}