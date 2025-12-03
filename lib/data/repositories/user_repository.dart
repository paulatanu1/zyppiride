import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  // Get user data once
  Future<UserModel> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        throw Exception('User not found');
      }

      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  // Watch user data (real-time updates)
  Stream<UserModel> watchUserData(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception('User not found');
      }
      return UserModel.fromFirestore(doc);
    });
  }

  // Update user data
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  // Mark notifications as read
  Future<void> markNotificationsRead(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationCount': 0,
      });
    } catch (e) {
      throw Exception('Failed to mark notifications as read: $e');
    }
  }
}
