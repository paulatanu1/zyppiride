// integration_test/e2e/helpers/firebase_test_helper.dart
// Firebase Test Helper for E2E Testing

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/e2e_test_config.dart';

/// Firebase Test Helper
/// Provides safe operations for E2E testing with isolated test collections
class FirebaseTestHelper {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get prefixed collection reference for test isolation
  CollectionReference<Map<String, dynamic>> getTestCollection(String baseName) {
    final collectionName = E2ETestConfig.getCollection(baseName);
    return _firestore.collection(collectionName);
  }

  // ============================
  // AUTH OPERATIONS
  // ============================

  /// Register a new test user
  Future<E2EAuthResult> registerUser(E2ETestUser testUser) async {
    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: testUser.email,
        password: testUser.password,
      );

      if (credential.user == null) {
        return E2EAuthResult.failure('User creation returned null');
      }

      // Update display name
      await credential.user!.updateDisplayName(testUser.fullName);

      // Create Firestore user document
      await getTestCollection('users').doc(credential.user!.uid).set({
        ...testUser.toFirestoreUser(),
        'userId': credential.user!.uid,
      });

      return E2EAuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // User exists, try to login instead
        return await loginUser(testUser);
      }
      return E2EAuthResult.failure('Auth error: ${e.message}');
    } catch (e) {
      return E2EAuthResult.failure('Registration failed: $e');
    }
  }

  /// Login an existing test user
  Future<E2EAuthResult> loginUser(E2ETestUser testUser) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: testUser.email,
        password: testUser.password,
      );

      if (credential.user == null) {
        return E2EAuthResult.failure('Login returned null user');
      }

      return E2EAuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return E2EAuthResult.failure('Auth error: ${e.code} - ${e.message}');
    } catch (e) {
      return E2EAuthResult.failure('Login failed: $e');
    }
  }

  /// Logout current user
  Future<bool> logout() async {
    try {
      await _auth.signOut();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // ============================
  // USER OPERATIONS
  // ============================

  /// Get user document from Firestore
  /// Checks both test collection and main collection
  Future<Map<String, dynamic>?> getUserDocument(String userId) async {
    try {
      // First try test collection
      var doc = await getTestCollection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }

      // Fallback to main collection (app writes here during actual flow)
      doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Update user document
  /// Tries both test collection and main collection
  Future<bool> updateUserDocument(
      String userId, Map<String, dynamic> data) async {
    try {
      // Try test collection first
      final testDoc = await getTestCollection('users').doc(userId).get();
      if (testDoc.exists) {
        await getTestCollection('users').doc(userId).update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Fallback to main collection
      final mainDoc = await _firestore.collection('users').doc(userId).get();
      if (mainDoc.exists) {
        await _firestore.collection('users').doc(userId).update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // If document doesn't exist, create it in main collection
      await _firestore.collection('users').doc(userId).set({
        ...data,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verify user role in Firestore
  Future<String?> getUserRole(String userId) async {
    final userData = await getUserDocument(userId);
    return userData?['role'] as String?;
  }

  // ============================
  // VEHICLE OPERATIONS
  // ============================

  /// Register a vehicle for a user
  Future<E2EVehicleResult> registerVehicle(
    String userId,
    E2ETestVehicle vehicle,
  ) async {
    try {
      final vehicleData = vehicle.toFirestore(userId);
      final docRef = await getTestCollection('vehicles').add(vehicleData);

      // Update the document with its own ID
      await docRef.update({'vehicleId': docRef.id});

      return E2EVehicleResult.success(docRef.id);
    } catch (e) {
      return E2EVehicleResult.failure('Vehicle registration failed: $e');
    }
  }

  /// Get vehicles for a user
  Future<List<Map<String, dynamic>>> getUserVehicles(String userId) async {
    try {
      final snapshot = await getTestCollection('vehicles')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if vehicle with registration exists
  Future<bool> vehicleExists(String registrationNumber) async {
    try {
      final snapshot = await getTestCollection('vehicles')
          .where('registrationNumber', isEqualTo: registrationNumber)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Update vehicle status
  Future<bool> updateVehicleStatus(
    String vehicleId,
    Map<String, dynamic> status,
  ) async {
    try {
      await getTestCollection('vehicles').doc(vehicleId).update({
        ...status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================
  // CLEANUP OPERATIONS
  // ============================

  /// Delete all test data for a specific user
  Future<void> cleanupUserData(String userId) async {
    try {
      // Delete user's vehicles
      final vehicles = await getTestCollection('vehicles')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in vehicles.docs) {
        await doc.reference.delete();
      }

      // Delete user's bookings
      final bookings = await getTestCollection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in bookings.docs) {
        await doc.reference.delete();
      }

      // Delete user document
      await getTestCollection('users').doc(userId).delete();
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Cleanup all E2E test data
  Future<void> cleanupAllTestData() async {
    final collections = ['users', 'vehicles', 'bookings', 'drivers'];

    for (final collection in collections) {
      try {
        final snapshot = await getTestCollection(collection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        // Ignore individual collection errors
      }
    }
  }

  /// Delete Firebase Auth user (if possible)
  Future<void> deleteAuthUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      // Ignore deletion errors
    }
  }

  // ============================
  // VALIDATION HELPERS
  // ============================

  /// Validate user document structure
  bool validateUserDocument(Map<String, dynamic>? data) {
    if (data == null) return false;

    final requiredFields = ['userId', 'email', 'fullName', 'role'];
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        return false;
      }
    }
    return true;
  }

  /// Validate vehicle document structure
  bool validateVehicleDocument(Map<String, dynamic>? data) {
    if (data == null) return false;

    final requiredFields = [
      'registrationNumber',
      'brand',
      'model',
      'vehicleType',
      'userId'
    ];
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        return false;
      }
    }
    return true;
  }
}

/// Auth operation result
class E2EAuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  E2EAuthResult._({
    required this.success,
    this.user,
    this.errorMessage,
  });

  factory E2EAuthResult.success(User user) =>
      E2EAuthResult._(success: true, user: user);

  factory E2EAuthResult.failure(String message) =>
      E2EAuthResult._(success: false, errorMessage: message);
}

/// Vehicle operation result
class E2EVehicleResult {
  final bool success;
  final String? vehicleId;
  final String? errorMessage;

  E2EVehicleResult._({
    required this.success,
    this.vehicleId,
    this.errorMessage,
  });

  factory E2EVehicleResult.success(String vehicleId) =>
      E2EVehicleResult._(success: true, vehicleId: vehicleId);

  factory E2EVehicleResult.failure(String message) =>
      E2EVehicleResult._(success: false, errorMessage: message);
}
