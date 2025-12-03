import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/banner_model.dart';

class BannerRepository {
  final FirebaseFirestore _firestore;

  BannerRepository(this._firestore);

  // Get active banners
  Future<List<BannerModel>> getActiveBanners() async {
    try {
      final querySnapshot = await _firestore
          .collection('banners')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => BannerModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch banners: $e');
    }
  }

  // Watch banners (real-time)
  Stream<List<BannerModel>> watchBanners() {
    return _firestore
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BannerModel.fromFirestore(doc))
              .toList(),
        );
  }
}
