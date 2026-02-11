// test/e2e_mock_test.dart
// Unit tests for E2E Mock Services - runs without device

import 'package:flutter_test/flutter_test.dart';

// Import mock services
import '../integration_test/mocks/mock_firebase_service.dart';
import '../integration_test/test_config.dart';
import '../integration_test/test_report_generator.dart';

void main() {
  late MockFirebaseService mockFirebase;
  late FirestoreAssertions assertions;

  setUpAll(() async {
    mockFirebase = MockFirebaseService();
    await mockFirebase.initializeTestData();
    assertions = FirestoreAssertions(mockFirebase.firestore);
  });

  group('Mock Firebase Service Tests', () {
    test('Mock Firestore is initialized', () {
      expect(mockFirebase.firestore, isNotNull);
    });

    test('Mock Auth is initialized', () {
      expect(mockFirebase.auth, isNotNull);
    });

    test('Mock Storage is initialized', () {
      expect(mockFirebase.storage, isNotNull);
    });
  });

  group('Users Collection Tests', () {
    test('Test user exists', () async {
      final exists = await assertions.documentExists('users', 'test_user_001');
      expect(exists, true);
    });

    test('Test driver exists', () async {
      final exists = await assertions.documentExists('users', 'test_driver_001');
      expect(exists, true);
    });

    test('Test owner exists', () async {
      final exists = await assertions.documentExists('users', 'test_owner_001');
      expect(exists, true);
    });

    test('User has correct email', () async {
      final doc = await mockFirebase.firestore
          .collection('users')
          .doc('test_user_001')
          .get();
      expect(doc.data()?['email'], TestConfig.testUserEmail);
    });

    test('Driver has correct role', () async {
      final doc = await mockFirebase.firestore
          .collection('users')
          .doc('test_driver_001')
          .get();
      expect(doc.data()?['role'], 'driver');
    });

    test('Owner has correct role', () async {
      final doc = await mockFirebase.firestore
          .collection('users')
          .doc('test_owner_001')
          .get();
      expect(doc.data()?['role'], 'owner');
    });
  });

  group('Vehicles Collection Tests', () {
    test('Vehicle 1 exists', () async {
      final exists = await assertions.documentExists('vehicles', 'test_vehicle_001');
      expect(exists, true);
    });

    test('Vehicle 2 exists', () async {
      final exists = await assertions.documentExists('vehicles', 'test_vehicle_002');
      expect(exists, true);
    });

    test('Vehicle 3 exists', () async {
      final exists = await assertions.documentExists('vehicles', 'test_vehicle_003');
      expect(exists, true);
    });

    test('Vehicle has correct owner', () async {
      final doc = await mockFirebase.firestore
          .collection('vehicles')
          .doc('test_vehicle_001')
          .get();
      expect(doc.data()?['userId'], 'test_owner_001');
    });

    test('Vehicle has correct status', () async {
      final doc = await mockFirebase.firestore
          .collection('vehicles')
          .doc('test_vehicle_001')
          .get();
      expect(doc.data()?['documentStatus'], 'approved');
    });

    test('Pending vehicle has pending status', () async {
      final doc = await mockFirebase.firestore
          .collection('vehicles')
          .doc('test_vehicle_003')
          .get();
      expect(doc.data()?['documentStatus'], 'pending');
    });

    test('Can query vehicles by owner', () async {
      final snapshot = await mockFirebase.firestore
          .collection('vehicles')
          .where('userId', isEqualTo: 'test_owner_001')
          .get();
      expect(snapshot.docs.length, 3);
    });

    test('Can query approved vehicles', () async {
      final snapshot = await mockFirebase.firestore
          .collection('vehicles')
          .where('documentStatus', isEqualTo: 'approved')
          .get();
      expect(snapshot.docs.length, 2);
    });
  });

  group('Bookings Collection Tests', () {
    test('In-progress booking exists', () async {
      final exists = await assertions.documentExists('bookings', 'test_booking_001');
      expect(exists, true);
    });

    test('Completed booking exists', () async {
      final exists = await assertions.documentExists('bookings', 'test_booking_002');
      expect(exists, true);
    });

    test('Cancelled booking exists', () async {
      final exists = await assertions.documentExists('bookings', 'test_booking_003');
      expect(exists, true);
    });

    test('In-progress booking has correct status', () async {
      final doc = await mockFirebase.firestore
          .collection('bookings')
          .doc('test_booking_001')
          .get();
      expect(doc.data()?['status'], 'in_progress');
    });

    test('Completed booking has rating', () async {
      final doc = await mockFirebase.firestore
          .collection('bookings')
          .doc('test_booking_002')
          .get();
      expect(doc.data()?['rating'], 5);
    });

    test('Cancelled booking has reason', () async {
      final doc = await mockFirebase.firestore
          .collection('bookings')
          .doc('test_booking_003')
          .get();
      expect(doc.data()?['cancellationReason'], isNotNull);
    });

    test('Can query user bookings', () async {
      final snapshot = await mockFirebase.firestore
          .collection('bookings')
          .where('userId', isEqualTo: 'test_user_001')
          .get();
      expect(snapshot.docs.length, 3);
    });
  });

  group('Offers Collection Tests', () {
    test('Offer 1 exists', () async {
      final exists = await assertions.documentExists('offers', 'offer_001');
      expect(exists, true);
    });

    test('Offer has correct code', () async {
      final doc = await mockFirebase.firestore
          .collection('offers')
          .doc('offer_001')
          .get();
      expect(doc.data()?['code'], 'FIRST20');
    });

    test('Can query active offers', () async {
      final snapshot = await mockFirebase.firestore
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .get();
      expect(snapshot.docs.length, 3);
    });
  });

  group('Banners Collection Tests', () {
    test('Banner 1 exists', () async {
      final exists = await assertions.documentExists('banners', 'banner_001');
      expect(exists, true);
    });

    test('Can query active banners', () async {
      final snapshot = await mockFirebase.firestore
          .collection('banners')
          .where('isActive', isEqualTo: true)
          .get();
      expect(snapshot.docs.length, 2);
    });
  });

  group('Vehicle Catalog Tests', () {
    test('Vehicle catalog exists', () async {
      final exists = await assertions.documentExists('vehicleCatalog', 'india2025');
      expect(exists, true);
    });

    test('Catalog has makes', () async {
      final doc = await mockFirebase.firestore
          .collection('vehicleCatalog')
          .doc('india2025')
          .get();
      final makes = doc.data()?['makes'] as Map<String, dynamic>?;
      expect(makes, isNotNull);
      expect(makes?.containsKey('Maruti'), true);
      expect(makes?.containsKey('Honda'), true);
      expect(makes?.containsKey('Toyota'), true);
    });

    test('Catalog has vehicle types', () async {
      final doc = await mockFirebase.firestore
          .collection('vehicleCatalog')
          .doc('india2025')
          .get();
      final types = doc.data()?['vehicleTypes'] as List?;
      expect(types, isNotNull);
      expect(types?.contains('Hatchback'), true);
      expect(types?.contains('Sedan'), true);
      expect(types?.contains('SUV'), true);
    });
  });

  group('Agreements Collection Tests', () {
    test('Driver agreement exists', () async {
      final exists = await assertions.documentExists('agreements', 'driver_agreement_v1');
      expect(exists, true);
    });

    test('Owner agreement exists', () async {
      final exists = await assertions.documentExists('agreements', 'owner_agreement_v1');
      expect(exists, true);
    });

    test('Driver agreement has correct type', () async {
      final doc = await mockFirebase.firestore
          .collection('agreements')
          .doc('driver_agreement_v1')
          .get();
      expect(doc.data()?['type'], 'driver');
    });
  });

  group('Authentication Tests', () {
    test('Can sign in test user', () async {
      await mockFirebase.signInTestUser(role: 'user');
      expect(mockFirebase.auth.currentUser, isNotNull);
      expect(mockFirebase.auth.currentUser?.uid, 'test_user_001');
    });

    test('Can sign in test driver', () async {
      await mockFirebase.signInTestUser(role: 'driver');
      expect(mockFirebase.auth.currentUser, isNotNull);
      expect(mockFirebase.auth.currentUser?.uid, 'test_driver_001');
    });

    test('Can sign in test owner', () async {
      await mockFirebase.signInTestUser(role: 'owner');
      expect(mockFirebase.auth.currentUser, isNotNull);
      expect(mockFirebase.auth.currentUser?.uid, 'test_owner_001');
    });

    test('Can sign out', () async {
      await mockFirebase.signInTestUser(role: 'user');
      expect(mockFirebase.auth.currentUser, isNotNull);

      await mockFirebase.signOut();
      expect(mockFirebase.auth.currentUser, isNull);
    });
  });

  group('CRUD Operations Tests', () {
    test('Can create document', () async {
      await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_create')
          .set({'field': 'value'});

      final doc = await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_create')
          .get();
      expect(doc.exists, true);
      expect(doc.data()?['field'], 'value');
    });

    test('Can update document', () async {
      await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_update')
          .set({'original': 'value'});

      await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_update')
          .update({'updated': 'new_value'});

      final doc = await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_update')
          .get();
      expect(doc.data()?['original'], 'value');
      expect(doc.data()?['updated'], 'new_value');
    });

    test('Can delete document', () async {
      await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_delete')
          .set({'to_delete': true});

      await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_delete')
          .delete();

      final doc = await mockFirebase.firestore
          .collection('test_crud')
          .doc('test_delete')
          .get();
      expect(doc.exists, false);
    });
  });

  group('Query Operations Tests', () {
    test('Can query with where clause', () async {
      final results = await mockFirebase.firestore
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();
      expect(results.docs.isNotEmpty, true);
    });

    test('Can query with multiple conditions', () async {
      final results = await mockFirebase.firestore
          .collection('vehicles')
          .where('userId', isEqualTo: 'test_owner_001')
          .where('documentStatus', isEqualTo: 'approved')
          .get();
      expect(results.docs.length, 2);
    });

    test('Can query with orderBy', () async {
      final results = await mockFirebase.firestore
          .collection('banners')
          .orderBy('order')
          .get();
      expect(results.docs.isNotEmpty, true);
    });

    test('Can query with limit', () async {
      final results = await mockFirebase.firestore
          .collection('vehicles')
          .limit(2)
          .get();
      expect(results.docs.length, lessThanOrEqualTo(2));
    });
  });

  group('Test Report Generator Tests', () {
    test('Can create test result', () {
      final result = TestResult(
        testName: 'Sample Test',
        category: 'Unit/Sample',
        passed: true,
        duration: Duration(milliseconds: 100),
      );
      expect(result.testName, 'Sample Test');
      expect(result.passed, true);
    });

    test('Can create test suite result', () {
      final results = [
        TestResult(
          testName: 'Test 1',
          category: 'Unit',
          passed: true,
          duration: Duration(milliseconds: 50),
        ),
        TestResult(
          testName: 'Test 2',
          category: 'Unit',
          passed: false,
          duration: Duration(milliseconds: 75),
          errorMessage: 'Test failed',
        ),
      ];

      final suite = TestSuiteResult(
        suiteName: 'Sample Suite',
        results: results,
        startTime: DateTime.now().subtract(Duration(seconds: 1)),
        endTime: DateTime.now(),
      );

      expect(suite.totalTests, 2);
      expect(suite.passedTests, 1);
      expect(suite.failedTests, 1);
      expect(suite.passRate, 50.0);
    });

    test('Can generate JSON report', () {
      final generator = TestReportGenerator();
      generator.addSuiteResult(TestSuiteResult(
        suiteName: 'Test Suite',
        results: [
          TestResult(
            testName: 'Test',
            category: 'Unit',
            passed: true,
            duration: Duration(milliseconds: 100),
          ),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      ));

      final json = generator.generateJsonReport();
      expect(json, contains('Test Suite'));
      expect(json, contains('"passed": true'));
    });

    test('Can generate Markdown report', () {
      final generator = TestReportGenerator();
      generator.addSuiteResult(TestSuiteResult(
        suiteName: 'Test Suite',
        results: [
          TestResult(
            testName: 'Test',
            category: 'Unit',
            passed: true,
            duration: Duration(milliseconds: 100),
          ),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      ));

      final md = generator.generateMarkdownReport();
      expect(md, contains('# Zyppi Ride'));
      expect(md, contains('Test Suite'));
    });
  });
}
