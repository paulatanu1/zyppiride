// integration_test/mocks/mock_firebase_service.dart
// Mock Firebase Services for E2E Testing
// Custom implementation to avoid dependency conflicts

import 'dart:async';
import '../test_config.dart';

/// Mock Document Snapshot
class MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;

  MockDocumentSnapshot({
    required this.id,
    Map<String, dynamic>? data,
    this.exists = true,
  }) : _data = data;

  Map<String, dynamic>? data() => _data;
}

/// Mock Query Document Snapshot
class MockQueryDocumentSnapshot extends MockDocumentSnapshot {
  MockQueryDocumentSnapshot({
    required super.id,
    required Map<String, dynamic> data,
  }) : super(data: data, exists: true);
}

/// Mock Query Snapshot
class MockQuerySnapshot {
  final List<MockQueryDocumentSnapshot> docs;

  MockQuerySnapshot(this.docs);
}

/// Mock Document Reference
class MockDocumentReference {
  final MockCollectionReference _collection;
  final String id;

  MockDocumentReference(this._collection, this.id);

  Future<void> set(Map<String, dynamic> data, [dynamic options]) async {
    _collection._documents[id] = Map<String, dynamic>.from(data);
  }

  Future<void> update(Map<String, dynamic> data) async {
    if (_collection._documents.containsKey(id)) {
      _collection._documents[id]!.addAll(data);
    }
  }

  Future<void> delete() async {
    _collection._documents.remove(id);
  }

  Future<MockDocumentSnapshot> get() async {
    final data = _collection._documents[id];
    return MockDocumentSnapshot(
      id: id,
      data: data,
      exists: data != null,
    );
  }

  MockCollectionReference collection(String path) {
    return _collection._firestore.collection('${_collection._path}/$id/$path');
  }
}

/// Mock Collection Reference
class MockCollectionReference {
  final MockFirestore _firestore;
  final String _path;
  final Map<String, Map<String, dynamic>> _documents = {};

  // Query state
  List<_QueryCondition> _conditions = [];
  String? _orderByField;
  bool _descending = false;
  int? _limitCount;
  MockDocumentSnapshot? _startAfterDoc;

  MockCollectionReference(this._firestore, this._path);

  MockDocumentReference doc(String id) {
    return MockDocumentReference(this, id);
  }

  Future<MockDocumentReference> add(Map<String, dynamic> data) async {
    final id = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    _documents[id] = Map<String, dynamic>.from(data);
    return MockDocumentReference(this, id);
  }

  MockCollectionReference where(String field, {dynamic isEqualTo, dynamic isGreaterThan, dynamic isLessThan}) {
    final newRef = MockCollectionReference(_firestore, _path);
    newRef._documents.addAll(_documents);
    newRef._conditions = List.from(_conditions);

    if (isEqualTo != null) {
      newRef._conditions.add(_QueryCondition(field, 'isEqualTo', isEqualTo));
    }
    if (isGreaterThan != null) {
      newRef._conditions.add(_QueryCondition(field, 'isGreaterThan', isGreaterThan));
    }
    if (isLessThan != null) {
      newRef._conditions.add(_QueryCondition(field, 'isLessThan', isLessThan));
    }

    return newRef;
  }

  MockCollectionReference orderBy(String field, {bool descending = false}) {
    final newRef = MockCollectionReference(_firestore, _path);
    newRef._documents.addAll(_documents);
    newRef._conditions = List.from(_conditions);
    newRef._orderByField = field;
    newRef._descending = descending;
    return newRef;
  }

  MockCollectionReference limit(int count) {
    final newRef = MockCollectionReference(_firestore, _path);
    newRef._documents.addAll(_documents);
    newRef._conditions = List.from(_conditions);
    newRef._orderByField = _orderByField;
    newRef._descending = _descending;
    newRef._limitCount = count;
    return newRef;
  }

  MockCollectionReference startAfterDocument(MockDocumentSnapshot doc) {
    final newRef = MockCollectionReference(_firestore, _path);
    newRef._documents.addAll(_documents);
    newRef._conditions = List.from(_conditions);
    newRef._orderByField = _orderByField;
    newRef._descending = _descending;
    newRef._limitCount = _limitCount;
    newRef._startAfterDoc = doc;
    return newRef;
  }

  Future<MockQuerySnapshot> get() async {
    var results = _documents.entries.toList();

    // Apply conditions
    for (var condition in _conditions) {
      results = results.where((entry) {
        final value = _getNestedValue(entry.value, condition.field);
        switch (condition.operator) {
          case 'isEqualTo':
            return value == condition.value;
          case 'isGreaterThan':
            if (value is num && condition.value is num) {
              return value > condition.value;
            }
            return false;
          case 'isLessThan':
            if (value is num && condition.value is num) {
              return value < condition.value;
            }
            return false;
          default:
            return true;
        }
      }).toList();
    }

    // Apply ordering
    if (_orderByField != null) {
      results.sort((a, b) {
        final aVal = _getNestedValue(a.value, _orderByField!);
        final bVal = _getNestedValue(b.value, _orderByField!);
        int comparison = 0;
        if (aVal is Comparable && bVal is Comparable) {
          comparison = aVal.compareTo(bVal);
        }
        return _descending ? -comparison : comparison;
      });
    }

    // Apply startAfter
    if (_startAfterDoc != null) {
      final startIndex = results.indexWhere((e) => e.key == _startAfterDoc!.id);
      if (startIndex >= 0) {
        results = results.sublist(startIndex + 1);
      }
    }

    // Apply limit
    if (_limitCount != null && results.length > _limitCount!) {
      results = results.sublist(0, _limitCount!);
    }

    return MockQuerySnapshot(
      results.map((e) => MockQueryDocumentSnapshot(id: e.key, data: e.value)).toList(),
    );
  }

  dynamic _getNestedValue(Map<String, dynamic> map, String path) {
    final parts = path.split('.');
    dynamic value = map;
    for (var part in parts) {
      if (value is Map) {
        value = value[part];
      } else {
        return null;
      }
    }
    return value;
  }
}

class _QueryCondition {
  final String field;
  final String operator;
  final dynamic value;

  _QueryCondition(this.field, this.operator, this.value);
}

/// Mock Firestore
class MockFirestore {
  final Map<String, MockCollectionReference> _collections = {};

  MockCollectionReference collection(String path) {
    return _collections.putIfAbsent(path, () => MockCollectionReference(this, path));
  }
}

/// Mock User
class MockUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final bool emailVerified;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.emailVerified = false,
  });
}

/// Mock Firebase Auth
class MockAuth {
  MockUser? _currentUser;
  final StreamController<MockUser?> _authStateController = StreamController<MockUser?>.broadcast();

  MockUser? get currentUser => _currentUser;

  Stream<MockUser?> authStateChanges() => _authStateController.stream;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _currentUser = MockUser(uid: 'test_uid', email: email);
    _authStateController.add(_currentUser);
  }

  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  void setMockUser(MockUser user) {
    _currentUser = user;
    _authStateController.add(_currentUser);
  }

  void dispose() {
    _authStateController.close();
  }
}

/// Mock Storage
class MockStorage {
  final Map<String, String> _files = {};

  Future<String> uploadFile(String path, dynamic file) async {
    final url = 'https://storage.mock.com/$path';
    _files[path] = url;
    return url;
  }

  Future<String?> getDownloadUrl(String path) async {
    return _files[path];
  }

  Future<void> deleteFile(String path) async {
    _files.remove(path);
  }
}

/// Mock Firebase Service Provider for testing
class MockFirebaseService {
  late final MockFirestore firestore;
  late MockAuth auth;
  late final MockStorage storage;

  MockFirebaseService() {
    firestore = MockFirestore();
    auth = MockAuth();
    storage = MockStorage();
  }

  /// Initialize with test data
  Future<void> initializeTestData() async {
    await _seedUsers();
    await _seedVehicles();
    await _seedVehicleCatalog();
    await _seedBookings();
    await _seedOffers();
    await _seedBanners();
    await _seedAgreements();
  }

  /// Seed test users
  Future<void> _seedUsers() async {
    // Test User (Regular)
    await firestore.collection('users').doc('test_user_001').set({
      'userId': 'test_user_001',
      'email': TestConfig.testUserEmail,
      'fullName': TestConfig.testUserName,
      'mobile': TestConfig.testUserPhone,
      'role': 'user',
      'createdAt': DateTime.now().toIso8601String(),
      'is_admin': false,
      'totalRides': 5,
      'rating': 4.8,
    });

    // Test Driver
    await firestore.collection('users').doc('test_driver_001').set({
      'userId': 'test_driver_001',
      'email': TestConfig.testDriverEmail,
      'fullName': TestConfig.testDriverName,
      'mobile': TestConfig.testDriverPhone,
      'role': 'driver',
      'createdAt': DateTime.now().toIso8601String(),
      'is_admin': false,
      'totalRides': 150,
      'rating': 4.9,
      'drivingLicenseNumber': 'DL123456789',
      'drivingLicenseValidUpto': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    });

    // Test Owner
    await firestore.collection('users').doc('test_owner_001').set({
      'userId': 'test_owner_001',
      'email': TestConfig.testOwnerEmail,
      'fullName': TestConfig.testOwnerName,
      'mobile': TestConfig.testOwnerPhone,
      'role': 'owner',
      'createdAt': DateTime.now().toIso8601String(),
      'is_admin': false,
      'totalVehicles': 3,
    });
  }

  /// Seed test vehicles
  Future<void> _seedVehicles() async {
    // Vehicle 1 - Hatchback
    await firestore.collection('vehicles').doc('test_vehicle_001').set({
      'userId': 'test_owner_001',
      'vehicleDetails': {
        'registrationNumber': 'KA01AB1234',
        'make': 'Maruti',
        'model': 'Swift',
        'type': 'Hatchback',
        'year': '2022',
        'color': 'White',
        'fuelType': 'Petrol',
        'seatingCapacity': 4,
      },
      'documents': {
        'vehicleImages': ['https://example.com/vehicle1.jpg'],
        'rcImages': ['https://example.com/rc1.jpg'],
        'licenseImages': [],
        'insuranceImages': ['https://example.com/insurance1.jpg'],
        'pucImages': ['https://example.com/puc1.jpg'],
      },
      'documentStatus': 'approved',
      'createdAt': DateTime.now().toIso8601String(),
      'location': {
        'city': 'Bangalore',
        'state': 'Karnataka',
        'pincode': '560001',
        'lat': 12.9716,
        'lng': 77.5946,
      },
      'availability': {
        'isOnline': true,
        'workingMode': 'always_available',
      },
    });

    // Vehicle 2 - Sedan
    await firestore.collection('vehicles').doc('test_vehicle_002').set({
      'userId': 'test_owner_001',
      'vehicleDetails': {
        'registrationNumber': 'KA01CD5678',
        'make': 'Honda',
        'model': 'City',
        'type': 'Sedan',
        'year': '2023',
        'color': 'Silver',
        'fuelType': 'Petrol',
        'seatingCapacity': 4,
      },
      'documents': {
        'vehicleImages': ['https://example.com/vehicle2.jpg'],
        'rcImages': ['https://example.com/rc2.jpg'],
        'licenseImages': [],
        'insuranceImages': ['https://example.com/insurance2.jpg'],
        'pucImages': ['https://example.com/puc2.jpg'],
      },
      'documentStatus': 'approved',
      'createdAt': DateTime.now().toIso8601String(),
      'location': {
        'city': 'Bangalore',
        'state': 'Karnataka',
        'pincode': '560002',
        'lat': 12.9816,
        'lng': 77.6046,
      },
      'availability': {
        'isOnline': true,
        'workingMode': 'day_shift',
      },
    });

    // Vehicle 3 - SUV (Pending approval)
    await firestore.collection('vehicles').doc('test_vehicle_003').set({
      'userId': 'test_owner_001',
      'vehicleDetails': {
        'registrationNumber': 'KA01EF9012',
        'make': 'Toyota',
        'model': 'Fortuner',
        'type': 'SUV',
        'year': '2024',
        'color': 'Black',
        'fuelType': 'Diesel',
        'seatingCapacity': 7,
      },
      'documents': {
        'vehicleImages': ['https://example.com/vehicle3.jpg'],
        'rcImages': [],
        'licenseImages': [],
        'insuranceImages': [],
        'pucImages': [],
      },
      'documentStatus': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'location': {
        'city': 'Bangalore',
        'state': 'Karnataka',
        'pincode': '560003',
      },
      'availability': {
        'isOnline': false,
        'workingMode': 'always_available',
      },
    });
  }

  /// Seed vehicle catalog
  Future<void> _seedVehicleCatalog() async {
    await firestore.collection('vehicleCatalog').doc('india2025').set({
      'makes': {
        'Maruti': {
          'models': ['Swift', 'Dzire', 'Baleno', 'Ertiga', 'Brezza', 'XL6'],
          'types': {
            'Swift': 'Hatchback',
            'Dzire': 'Sedan',
            'Baleno': 'Hatchback',
            'Ertiga': 'MUV',
            'Brezza': 'SUV',
            'XL6': 'MUV',
          },
        },
        'Honda': {
          'models': ['City', 'Amaze', 'Elevate', 'WR-V'],
          'types': {
            'City': 'Sedan',
            'Amaze': 'Sedan',
            'Elevate': 'SUV',
            'WR-V': 'SUV',
          },
        },
        'Toyota': {
          'models': ['Innova', 'Fortuner', 'Urban Cruiser', 'Glanza'],
          'types': {
            'Innova': 'MUV',
            'Fortuner': 'SUV',
            'Urban Cruiser': 'SUV',
            'Glanza': 'Hatchback',
          },
        },
        'Hyundai': {
          'models': ['i20', 'Verna', 'Creta', 'Venue', 'Alcazar'],
          'types': {
            'i20': 'Hatchback',
            'Verna': 'Sedan',
            'Creta': 'SUV',
            'Venue': 'SUV',
            'Alcazar': 'SUV',
          },
        },
        'Tata': {
          'models': ['Nexon', 'Punch', 'Harrier', 'Safari', 'Altroz'],
          'types': {
            'Nexon': 'SUV',
            'Punch': 'SUV',
            'Harrier': 'SUV',
            'Safari': 'SUV',
            'Altroz': 'Hatchback',
          },
        },
      },
      'vehicleTypes': ['Hatchback', 'Sedan', 'SUV', 'MUV', 'Bike', 'Auto'],
      'fuelTypes': ['Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid'],
      'colors': ['White', 'Black', 'Silver', 'Red', 'Blue', 'Grey', 'Brown', 'Green'],
      'seatingOptions': [2, 4, 5, 6, 7, 8],
    });
  }

  /// Seed test bookings
  Future<void> _seedBookings() async {
    // Active booking
    await firestore.collection('bookings').doc('test_booking_001').set({
      'bookingId': 'test_booking_001',
      'userId': 'test_user_001',
      'vehicleId': 'test_vehicle_001',
      'driverId': 'test_driver_001',
      'status': 'in_progress',
      'pickup': {
        'address': '123 MG Road, Bangalore',
        'lat': 12.9716,
        'lng': 77.5946,
      },
      'drop': {
        'address': '456 Koramangala, Bangalore',
        'lat': 12.9352,
        'lng': 77.6244,
      },
      'fare': 350.0,
      'distance': 8.5,
      'duration': 25,
      'createdAt': DateTime.now().toIso8601String(),
      'acceptedAt': DateTime.now().toIso8601String(),
    });

    // Completed booking
    await firestore.collection('bookings').doc('test_booking_002').set({
      'bookingId': 'test_booking_002',
      'userId': 'test_user_001',
      'vehicleId': 'test_vehicle_002',
      'driverId': 'test_driver_001',
      'status': 'completed',
      'pickup': {
        'address': '789 Indiranagar, Bangalore',
        'lat': 12.9784,
        'lng': 77.6408,
      },
      'drop': {
        'address': '012 Whitefield, Bangalore',
        'lat': 12.9698,
        'lng': 77.7499,
      },
      'fare': 550.0,
      'distance': 15.2,
      'duration': 45,
      'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'completedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'rating': 5,
      'feedback': 'Great service!',
    });

    // Cancelled booking
    await firestore.collection('bookings').doc('test_booking_003').set({
      'bookingId': 'test_booking_003',
      'userId': 'test_user_001',
      'vehicleId': 'test_vehicle_001',
      'status': 'cancelled',
      'pickup': {
        'address': 'HSR Layout, Bangalore',
        'lat': 12.9116,
        'lng': 77.6474,
      },
      'drop': {
        'address': 'Electronic City, Bangalore',
        'lat': 12.8458,
        'lng': 77.6692,
      },
      'fare': 450.0,
      'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'cancelledAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'cancellationReason': 'Driver not available',
    });
  }

  /// Seed offers
  Future<void> _seedOffers() async {
    await firestore.collection('offers').doc('offer_001').set({
      'offerId': 'offer_001',
      'code': 'FIRST20',
      'title': 'First Ride Discount',
      'description': 'Get 20% off on your first ride',
      'discountType': 'percentage',
      'discountValue': 20.0,
      'minBookingAmount': 100.0,
      'maxDiscount': 100.0,
      'validFrom': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'validTo': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'usageLimit': 1000,
      'usedCount': 150,
      'isActive': true,
      'targetUserType': 'new',
    });

    await firestore.collection('offers').doc('offer_002').set({
      'offerId': 'offer_002',
      'code': 'WEEKEND15',
      'title': 'Weekend Special',
      'description': 'Get 15% off on weekend rides',
      'discountType': 'percentage',
      'discountValue': 15.0,
      'minBookingAmount': 200.0,
      'maxDiscount': 75.0,
      'validFrom': DateTime.now().toIso8601String(),
      'validTo': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'usageLimit': 500,
      'usedCount': 50,
      'isActive': true,
      'targetUserType': 'all',
    });

    await firestore.collection('offers').doc('offer_003').set({
      'offerId': 'offer_003',
      'code': 'FLAT50',
      'title': 'Flat 50 Off',
      'description': 'Get flat Rs.50 off on rides above Rs.300',
      'discountType': 'flat',
      'discountValue': 50.0,
      'minBookingAmount': 300.0,
      'maxDiscount': 50.0,
      'validFrom': DateTime.now().toIso8601String(),
      'validTo': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      'usageLimit': 2000,
      'usedCount': 500,
      'isActive': true,
      'targetUserType': 'all',
    });
  }

  /// Seed banners
  Future<void> _seedBanners() async {
    await firestore.collection('banners').doc('banner_001').set({
      'bannerId': 'banner_001',
      'title': 'Welcome to Zyppi Ride',
      'subtitle': 'Your trusted ride partner',
      'imageUrl': 'https://example.com/banner1.jpg',
      'isActive': true,
      'order': 1,
      'targetType': 'screen',
      'targetValue': '/offers',
    });

    await firestore.collection('banners').doc('banner_002').set({
      'bannerId': 'banner_002',
      'title': 'Safe Rides',
      'subtitle': 'Verified drivers, safe journeys',
      'imageUrl': 'https://example.com/banner2.jpg',
      'isActive': true,
      'order': 2,
      'targetType': 'url',
      'targetValue': 'https://zyppiride.com/safety',
    });

    await firestore.collection('offer_banners').doc('offer_banner_001').set({
      'bannerId': 'offer_banner_001',
      'offerId': 'offer_001',
      'imageUrl': 'https://example.com/offer_banner1.jpg',
      'isActive': true,
      'order': 1,
    });
  }

  /// Seed agreements
  Future<void> _seedAgreements() async {
    await firestore.collection('agreements').doc('driver_agreement_v1').set({
      'agreementId': 'driver_agreement_v1',
      'type': 'driver',
      'version': '1.0',
      'title': 'Driver Partner Agreement',
      'content': '''
DRIVER PARTNER AGREEMENT

This Agreement is entered into between Zyppi Ride ("Company") and the Driver Partner ("Partner").

1. SERVICES
The Partner agrees to provide transportation services to users of the Zyppi Ride platform.

2. REQUIREMENTS
- Valid driving license
- Vehicle registration documents
- Insurance documents
- Background verification

3. COMMISSION
The Company will charge a service fee of 20% on each completed ride.

4. CONDUCT
The Partner agrees to maintain professional conduct at all times.

5. TERMINATION
Either party may terminate this agreement with 7 days notice.
''',
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    });

    await firestore.collection('agreements').doc('owner_agreement_v1').set({
      'agreementId': 'owner_agreement_v1',
      'type': 'owner',
      'version': '1.0',
      'title': 'Vehicle Owner Agreement',
      'content': '''
VEHICLE OWNER AGREEMENT

This Agreement is entered into between Zyppi Ride ("Company") and the Vehicle Owner ("Owner").

1. VEHICLE REGISTRATION
The Owner agrees to register their vehicle(s) on the platform with valid documents.

2. DOCUMENTATION
Required documents:
- Vehicle RC
- Insurance
- PUC Certificate

3. EARNINGS
Earnings will be credited to the Owner's account within 7 working days.

4. MAINTENANCE
The Owner is responsible for vehicle maintenance and upkeep.
''',
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    });
  }

  /// Clear all test data
  Future<void> clearAllData() async {
    // Clear collections by resetting firestore
    // Note: In this mock, we'd need to recreate the firestore instance
  }

  /// Create a mock authenticated user
  Future<void> signInTestUser({String role = 'user'}) async {
    String email;
    String uid;
    String name;

    switch (role) {
      case 'driver':
        email = TestConfig.testDriverEmail;
        uid = 'test_driver_001';
        name = TestConfig.testDriverName;
        break;
      case 'owner':
        email = TestConfig.testOwnerEmail;
        uid = 'test_owner_001';
        name = TestConfig.testOwnerName;
        break;
      default:
        email = TestConfig.testUserEmail;
        uid = 'test_user_001';
        name = TestConfig.testUserName;
    }

    auth.setMockUser(MockUser(
      uid: uid,
      email: email,
      displayName: name,
    ));
  }

  /// Sign out current user
  Future<void> signOut() async {
    await auth.signOut();
  }
}

/// Test data assertions helper
class FirestoreAssertions {
  final MockFirestore firestore;

  FirestoreAssertions(this.firestore);

  /// Assert document exists
  Future<bool> documentExists(String collection, String docId) async {
    final doc = await firestore.collection(collection).doc(docId).get();
    return doc.exists;
  }

  /// Assert document has field
  Future<bool> documentHasField(String collection, String docId, String field) async {
    final doc = await firestore.collection(collection).doc(docId).get();
    return doc.exists && doc.data()?.containsKey(field) == true;
  }

  /// Assert document field value
  Future<bool> documentFieldEquals(String collection, String docId, String field, dynamic value) async {
    final doc = await firestore.collection(collection).doc(docId).get();
    return doc.exists && doc.data()?[field] == value;
  }

  /// Assert collection count
  Future<int> collectionCount(String collection) async {
    final snapshot = await firestore.collection(collection).get();
    return snapshot.docs.length;
  }

  /// Assert query returns results
  Future<bool> queryHasResults(String collection, String field, dynamic value, {int expectedCount = 1}) async {
    final snapshot = await firestore.collection(collection).where(field, isEqualTo: value).get();
    return snapshot.docs.length >= expectedCount;
  }
}
