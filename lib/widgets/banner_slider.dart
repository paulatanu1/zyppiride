// lib/screens/user/widgets/banner_slider.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:ui';

class BannerSlider extends StatefulWidget {
  final List<BannerItem> banners;
  final Function(String?)? onBannerTap;

  const BannerSlider({super.key, required this.banners, this.onBannerTap});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          items: widget.banners.map((banner) {
            return Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  onTap: () => widget.onBannerTap?.call(banner.actionRoute),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image
                          Image.network(
                            banner.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepPurple.shade400,
                                      Colors.deepPurple.shade700,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.image,
                                  size: 64,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          ),
                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.5),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                          // Content
                          Positioned(
                            bottom: 24,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  banner.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner.subtitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // CTA Button
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Book Now',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                      fontFamily: 'Poppins',
                                    ),
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
              },
            );
          }).toList(),
          options: CarouselOptions(
            height: 200,
            autoPlay: true,
            enlargeCenterPage: true,
            aspectRatio: 16 / 9,
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            viewportFraction: 0.88,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        // Animated Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.banners.asMap().entries.map((entry) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentIndex == entry.key ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentIndex == entry.key
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class BannerItem {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? actionRoute;

  BannerItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.actionRoute,
  });
}
