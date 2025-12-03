import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final FirebaseFirestore _firestore;

  BookingRepository(this._firestore);

  // Watch active booking (real-time)
  Stream<ActiveBooking?> watchActiveBooking(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where(
          'status',
          whereIn: ['pending', 'active', 'in_progress', 'confirmed'],
        )
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          return ActiveBooking.fromFirestore(snapshot.docs.first);
        });
  }

  // Get booking history
  Future<List<BookingModel>> getBookingHistory(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch booking history: $e');
    }
  }

  // Get specific booking
  Future<BookingModel> getBooking(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();

      if (!doc.exists) {
        throw Exception('Booking not found');
      }

      return BookingModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch booking: $e');
    }
  }
}
