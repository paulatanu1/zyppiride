import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer_banner_model.dart';

class OfferBannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'offer_banners';

  /// Add a single offer banner
  Future<String> addOfferBanner(OfferBannerData banner) async {
    final docRef = await _firestore.collection(_collection).add(banner.toJson());
    return docRef.id;
  }

  /// Update an existing offer banner
  Future<void> updateOfferBanner(String id, OfferBannerData banner) async {
    await _firestore.collection(_collection).doc(id).update(banner.toJson());
  }

  /// Delete an offer banner
  Future<void> deleteOfferBanner(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Toggle offer banner active status
  Future<void> toggleOfferBannerStatus(String id, bool isActive) async {
    await _firestore.collection(_collection).doc(id).update({
      'isActive': isActive,
    });
  }

  /// Seed sample offer banners (for initial setup/testing)
  Future<void> seedSampleOfferBanners() async {
    final sampleBanners = [
      OfferBannerData(
        id: '',
        imageUrl: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800',
        title: 'First Ride Bonus',
        subtitle: 'Get amazing discount on your first ride with us',
        discount: '50% OFF',
        promoCode: 'FIRST50',
        actionRoute: 'offersRewards',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        priority: 3,
      ),
      OfferBannerData(
        id: '',
        imageUrl: 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=800',
        title: 'Weekend Special',
        subtitle: 'Book any ride this weekend and save big',
        discount: '30% OFF',
        promoCode: 'WEEKEND30',
        actionRoute: 'reserveVehicle',
        expiryDate: DateTime.now().add(const Duration(days: 15)),
        isActive: true,
        priority: 2,
      ),
      OfferBannerData(
        id: '',
        imageUrl: 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=800',
        title: 'Refer & Earn',
        subtitle: 'Invite friends and earn rewards on every referral',
        discount: 'Up to ₹500',
        promoCode: 'REFER500',
        isActive: true,
        priority: 1,
      ),
    ];

    for (final banner in sampleBanners) {
      await addOfferBanner(banner);
    }
  }

  /// Clear all offer banners (use with caution)
  Future<void> clearAllOfferBanners() async {
    final snapshots = await _firestore.collection(_collection).get();
    for (final doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
