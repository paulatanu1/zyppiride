import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/offer_model.dart';
import '../../providers/user_dashboard_provider.dart';

class OffersRewardsScreen extends ConsumerStatefulWidget {
  const OffersRewardsScreen({super.key});

  @override
  ConsumerState<OffersRewardsScreen> createState() => _OffersRewardsScreenState();
}

class _OffersRewardsScreenState extends ConsumerState<OffersRewardsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  // Offers are loaded live from Firestore via offersProvider — no hardcoded list.
  static const List<Color> _offerPalette = [
    Colors.purple, Colors.blue, Colors.green,
    Colors.orange, Colors.red, Colors.teal,
  ];

  Map<String, dynamic> _offerToMap(OfferData offer, int index) {
    return {
      'title':       offer.title,
      'discount':    offer.discount.isNotEmpty ? offer.discount : 'Special Offer',
      'description': offer.description,
      'code':        offer.code,
      'minOrder':    offer.minOrder.isNotEmpty ? offer.minOrder : 'No minimum',
      'validTill':   offer.validTill.isNotEmpty ? offer.validTill : 'Limited time',
      'color':       _offerPalette[index % _offerPalette.length],
      'used':        offer.isUsed,
    };
  }

  final List<Map<String, dynamic>> _rewards = [
    {'icon': Icons.star, 'label': 'Points', 'value': '1,250', 'color': Colors.amber},
    {'icon': Icons.local_offer, 'label': 'Coupons', 'value': '3', 'color': Colors.green},
    {'icon': Icons.card_giftcard, 'label': 'Rewards', 'value': '2', 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                _buildRewardsCard(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOffersTab(),
                      _buildMyRewardsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/user-dashboard');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Offers & Rewards',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '1,250',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade400,
              Colors.orange.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _rewards.map((r) => _buildRewardItem(r)).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete 5 more rides to unlock Gold membership!',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem(Map<String, dynamic> reward) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(reward['icon'], color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          reward['value'],
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          reward['label'],
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.white,
          labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Offers'),
            Tab(text: 'My Rewards'),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    final offersAsync = ref.watch(offersProvider);

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            Text(
              'Unable to load offers',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      data: (offers) {
        if (offers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer_outlined, color: Colors.grey.shade300, size: 72),
                const SizedBox(height: 16),
                Text(
                  'No offers available',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back soon for new deals',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            return _buildOfferCard(_offerToMap(offers[index], index));
          },
        );
      },
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (offer['color'] as Color).withValues(alpha: 0.8),
                  offer['color'] as Color,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer['title'],
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        offer['validTill'],
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    offer['discount'],
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: offer['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer['description'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildOfferTag('Min: ${offer['minOrder']}'),
                    const SizedBox(width: 8),
                    _buildOfferTag('Code: ${offer['code']}'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              offer['code'],
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                                letterSpacing: 2,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _copyCode(offer['code']),
                              child: const Icon(Icons.copy, color: Colors.deepPurple, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Apply offer
                        context.go('/reserve-vehicle');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: offer['color'] as Color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildMyRewardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Points History',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildPointsHistoryItem('+50', 'Completed ride to Airport', '2 hours ago', true),
          _buildPointsHistoryItem('+25', 'Completed ride to Park Street', 'Yesterday', true),
          _buildPointsHistoryItem('-100', 'Redeemed for ₹50 off', '3 days ago', false),
          _buildPointsHistoryItem('+50', 'Completed ride to Salt Lake', '4 days ago', true),
          _buildPointsHistoryItem('+100', 'Referral bonus - Amit joined', '1 week ago', true),
          const SizedBox(height: 24),
          Text(
            'Redeem Points',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildRedeemCard('500 Points', '₹25 Off', 'Next ride discount'),
          _buildRedeemCard('1000 Points', '₹50 Off', 'Next ride discount'),
          _buildRedeemCard('2000 Points', '₹100 Off', 'Any ride discount'),
        ],
      ),
    );
  }

  Widget _buildPointsHistoryItem(String points, String title, String time, bool isCredit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.add : Icons.remove,
              color: isCredit ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemCard(String points, String value, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.stars, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Redeem points
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              points,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Code "$code" copied to clipboard',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
