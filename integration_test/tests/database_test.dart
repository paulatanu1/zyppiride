// integration_test/tests/database_test.dart
// E2E Tests for Firebase Database Interactions

import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_firebase_service.dart';
import '../test_report_generator.dart';

/// Database Interaction E2E Tests
class DatabaseTests {
  final TestRunner testRunner;
  final MockFirebaseService mockFirebase;
  late FirestoreAssertions firestoreAssertions;

  DatabaseTests({
    required this.testRunner,
    required this.mockFirebase,
  }) {
    firestoreAssertions = FirestoreAssertions(mockFirebase.firestore);
  }

  /// Run all database tests
  Future<void> runAllTests(WidgetTester tester) async {
    testRunner.startSuite('Database Interaction Tests');

    // Collection Structure Tests
    await _testUsersCollectionStructure(tester);
    await _testVehiclesCollectionStructure(tester);
    await _testBookingsCollectionStructure(tester);
    await _testVehicleCatalogStructure(tester);
    await _testOffersCollectionStructure(tester);
    await _testBannersCollectionStructure(tester);
    await _testAgreementsCollectionStructure(tester);

    // CRUD Operations Tests
    await _testCreateDocument(tester);
    await _testReadDocument(tester);
    await _testUpdateDocument(tester);
    await _testDeleteDocument(tester);

    // Query Tests
    await _testQueryByField(tester);
    await _testQueryWithMultipleConditions(tester);
    await _testQueryOrdering(tester);
    await _testQueryLimit(tester);
    await _testQueryPagination(tester);

    // Relationship Tests
    await _testUserVehicleRelationship(tester);
    await _testBookingRelationships(tester);
    await _testSubcollections(tester);

    // Data Integrity Tests
    await _testRequiredFieldsEnforcement(tester);
    await _testDataTypeValidation(tester);
    await _testTimestampHandling(tester);

    // Edge Case Tests
    await _testEmptyCollectionQuery(tester);
    await _testNonExistentDocument(tester);
    await _testLargeDataHandling(tester);

    // Index Tests
    await _testCompositeQueries(tester);
  }

  // ==========================================
  // COLLECTION STRUCTURE TESTS
  // ==========================================

  Future<void> _testUsersCollectionStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Users collection has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final user = await mockFirebase.firestore
            .collection('users')
            .doc('test_user_001')
            .get();

        expect(user.exists, true);

        final data = user.data()!;
        // Required fields
        expect(data.containsKey('userId'), true);
        expect(data.containsKey('email'), true);
        expect(data.containsKey('fullName'), true);
        expect(data.containsKey('role'), true);
        expect(data.containsKey('createdAt'), true);

        // Optional fields
        expect(data.containsKey('mobile'), true);
        expect(data.containsKey('profileImageUrl'), isIn([true, false]));
      },
    );
  }

  Future<void> _testVehiclesCollectionStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicles collection has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final vehicle = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        expect(vehicle.exists, true);

        final data = vehicle.data()!;
        expect(data.containsKey('userId'), true);
        expect(data.containsKey('vehicleDetails'), true);
        expect(data.containsKey('documents'), true);
        expect(data.containsKey('documentStatus'), true);
        expect(data.containsKey('location'), true);
        expect(data.containsKey('availability'), true);
        expect(data.containsKey('createdAt'), true);

        // Nested vehicle details
        final vehicleDetails = data['vehicleDetails'] as Map<String, dynamic>;
        expect(vehicleDetails.containsKey('registrationNumber'), true);
        expect(vehicleDetails.containsKey('make'), true);
        expect(vehicleDetails.containsKey('model'), true);
        expect(vehicleDetails.containsKey('type'), true);
      },
    );
  }

  Future<void> _testBookingsCollectionStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Bookings collection has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        expect(booking.exists, true);

        final data = booking.data()!;
        expect(data.containsKey('bookingId'), true);
        expect(data.containsKey('userId'), true);
        expect(data.containsKey('status'), true);
        expect(data.containsKey('pickup'), true);
        expect(data.containsKey('drop'), true);
        expect(data.containsKey('fare'), true);
        expect(data.containsKey('createdAt'), true);

        // Pickup structure
        final pickup = data['pickup'] as Map<String, dynamic>;
        expect(pickup.containsKey('address'), true);
        expect(pickup.containsKey('lat'), true);
        expect(pickup.containsKey('lng'), true);
      },
    );
  }

  Future<void> _testVehicleCatalogStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle catalog has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final catalog = await mockFirebase.firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get();

        expect(catalog.exists, true);

        final data = catalog.data()!;
        expect(data.containsKey('makes'), true);
        expect(data.containsKey('vehicleTypes'), true);
        expect(data.containsKey('fuelTypes'), true);

        // Check makes structure
        final makes = data['makes'] as Map<String, dynamic>;
        expect(makes.isNotEmpty, true);
      },
    );
  }

  Future<void> _testOffersCollectionStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Offers collection has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final offer = await mockFirebase.firestore
            .collection('offers')
            .doc('offer_001')
            .get();

        expect(offer.exists, true);

        final data = offer.data()!;
        expect(data.containsKey('code'), true);
        expect(data.containsKey('title'), true);
        expect(data.containsKey('discountType'), true);
        expect(data.containsKey('discountValue'), true);
        expect(data.containsKey('validFrom'), true);
        expect(data.containsKey('validTo'), true);
        expect(data.containsKey('isActive'), true);
      },
    );
  }

  Future<void> _testBannersCollectionStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Banners collection has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final banner = await mockFirebase.firestore
            .collection('banners')
            .doc('banner_001')
            .get();

        expect(banner.exists, true);

        final data = banner.data()!;
        expect(data.containsKey('title'), true);
        expect(data.containsKey('imageUrl'), true);
        expect(data.containsKey('isActive'), true);
        expect(data.containsKey('order'), true);
      },
    );
  }

  Future<void> _testAgreementsCollectionStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Agreements collection has correct structure',
      category: 'Database/Structure',
      testFunction: () async {
        final agreement = await mockFirebase.firestore
            .collection('agreements')
            .doc('driver_agreement_v1')
            .get();

        expect(agreement.exists, true);

        final data = agreement.data()!;
        expect(data.containsKey('type'), true);
        expect(data.containsKey('version'), true);
        expect(data.containsKey('title'), true);
        expect(data.containsKey('content'), true);
        expect(data.containsKey('isActive'), true);
      },
    );
  }

  // ==========================================
  // CRUD OPERATIONS TESTS
  // ==========================================

  Future<void> _testCreateDocument(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Document can be created',
      category: 'Database/CRUD',
      testFunction: () async {
        final docId = 'test_crud_create_${DateTime.now().millisecondsSinceEpoch}';

        await mockFirebase.firestore.collection('test_crud').doc(docId).set({
          'field1': 'value1',
          'field2': 123,
          'field3': true,
          'createdAt': DateTime.now(),
        });

        final doc =
            await mockFirebase.firestore.collection('test_crud').doc(docId).get();

        expect(doc.exists, true);
        expect(doc.data()!['field1'], 'value1');
        expect(doc.data()!['field2'], 123);
        expect(doc.data()!['field3'], true);
      },
    );
  }

  Future<void> _testReadDocument(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Document can be read',
      category: 'Database/CRUD',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('users')
            .doc('test_user_001')
            .get();

        expect(doc.exists, true);
        expect(doc.id, 'test_user_001');
        expect(doc.data(), isNotNull);
      },
    );
  }

  Future<void> _testUpdateDocument(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Document can be updated',
      category: 'Database/CRUD',
      testFunction: () async {
        // Create test document
        await mockFirebase.firestore.collection('test_crud').doc('test_update').set({
          'originalValue': 'original',
        });

        // Update document
        await mockFirebase.firestore.collection('test_crud').doc('test_update').update({
          'originalValue': 'updated',
          'newField': 'new value',
        });

        final doc =
            await mockFirebase.firestore.collection('test_crud').doc('test_update').get();

        expect(doc.data()!['originalValue'], 'updated');
        expect(doc.data()!['newField'], 'new value');
      },
    );
  }

  Future<void> _testDeleteDocument(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Document can be deleted',
      category: 'Database/CRUD',
      testFunction: () async {
        // Create test document
        await mockFirebase.firestore.collection('test_crud').doc('test_delete').set({
          'toDelete': true,
        });

        // Delete document
        await mockFirebase.firestore.collection('test_crud').doc('test_delete').delete();

        final doc =
            await mockFirebase.firestore.collection('test_crud').doc('test_delete').get();

        expect(doc.exists, false);
      },
    );
  }

  // ==========================================
  // QUERY TESTS
  // ==========================================

  Future<void> _testQueryByField(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Query by single field works',
      category: 'Database/Query',
      testFunction: () async {
        final results = await mockFirebase.firestore
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .get();

        expect(results.docs.isNotEmpty, true);
        for (var doc in results.docs) {
          expect(doc.data()?['role'], 'driver');
        }
      },
    );
  }

  Future<void> _testQueryWithMultipleConditions(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Query with multiple conditions works',
      category: 'Database/Query',
      testFunction: () async {
        final results = await mockFirebase.firestore
            .collection('vehicles')
            .where('userId', isEqualTo: 'test_owner_001')
            .where('documentStatus', isEqualTo: 'approved')
            .get();

        expect(results.docs.isNotEmpty, true);
        for (var doc in results.docs) {
          expect(doc.data()?['userId'], 'test_owner_001');
          expect(doc.data()?['documentStatus'], 'approved');
        }
      },
    );
  }

  Future<void> _testQueryOrdering(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Query with ordering works',
      category: 'Database/Query',
      testFunction: () async {
        final results = await mockFirebase.firestore
            .collection('banners')
            .orderBy('order')
            .get();

        expect(results.docs.isNotEmpty, true);

        // Verify ordering
        int previousOrder = -1;
        for (var doc in results.docs) {
          final currentOrder = (doc.data()?['order'] ?? 0) as int;
          expect(currentOrder >= previousOrder, true);
          previousOrder = currentOrder;
        }
      },
    );
  }

  Future<void> _testQueryLimit(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Query with limit works',
      category: 'Database/Query',
      testFunction: () async {
        final results = await mockFirebase.firestore
            .collection('vehicles')
            .limit(2)
            .get();

        expect(results.docs.length, lessThanOrEqualTo(2));
      },
    );
  }

  Future<void> _testQueryPagination(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Query pagination works',
      category: 'Database/Query',
      testFunction: () async {
        // First page
        final firstPage = await mockFirebase.firestore
            .collection('vehicles')
            .limit(1)
            .get();

        expect(firstPage.docs.isNotEmpty, true);

        if (firstPage.docs.isNotEmpty) {
          // Second page (if more docs exist)
          final secondPage = await mockFirebase.firestore
              .collection('vehicles')
              .startAfterDocument(firstPage.docs.last)
              .limit(1)
              .get();

          // Second page might or might not have documents
          expect(secondPage.docs.length, lessThanOrEqualTo(1));
        }
      },
    );
  }

  // ==========================================
  // RELATIONSHIP TESTS
  // ==========================================

  Future<void> _testUserVehicleRelationship(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'User-Vehicle relationship is correct',
      category: 'Database/Relations',
      testFunction: () async {
        // Get owner
        final owner = await mockFirebase.firestore
            .collection('users')
            .doc('test_owner_001')
            .get();

        expect(owner.exists, true);
        expect(owner.data()!['role'], 'owner');

        // Get owner's vehicles
        final vehicles = await mockFirebase.firestore
            .collection('vehicles')
            .where('userId', isEqualTo: 'test_owner_001')
            .get();

        expect(vehicles.docs.isNotEmpty, true);
        expect(vehicles.docs.length, 3); // 3 test vehicles
      },
    );
  }

  Future<void> _testBookingRelationships(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking relationships are correct',
      category: 'Database/Relations',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        final userId = booking.data()!['userId'];
        final vehicleId = booking.data()!['vehicleId'];
        final driverId = booking.data()!['driverId'];

        // Verify user exists
        final user =
            await mockFirebase.firestore.collection('users').doc(userId).get();
        expect(user.exists, true);

        // Verify vehicle exists
        final vehicle = await mockFirebase.firestore
            .collection('vehicles')
            .doc(vehicleId)
            .get();
        expect(vehicle.exists, true);

        // Verify driver exists
        final driver =
            await mockFirebase.firestore.collection('users').doc(driverId).get();
        expect(driver.exists, true);
      },
    );
  }

  Future<void> _testSubcollections(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Subcollections work correctly',
      category: 'Database/Relations',
      testFunction: () async {
        // Create a subcollection
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .collection('maintenance')
            .doc('record_001')
            .set({
          'date': DateTime.now(),
          'type': 'oil_change',
          'cost': 500.0,
        });

        final maintenance = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .collection('maintenance')
            .doc('record_001')
            .get();

        expect(maintenance.exists, true);
        expect(maintenance.data()!['type'], 'oil_change');
      },
    );
  }

  // ==========================================
  // DATA INTEGRITY TESTS
  // ==========================================

  Future<void> _testRequiredFieldsEnforcement(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Required fields are enforced at application level',
      category: 'Database/Integrity',
      testFunction: () async {
        // Validate user required fields
        final user = await mockFirebase.firestore
            .collection('users')
            .doc('test_user_001')
            .get();

        final data = user.data()!;
        expect(data['email'], isNotNull);
        expect(data['role'], isNotNull);
      },
    );
  }

  Future<void> _testDataTypeValidation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Data types are correct',
      category: 'Database/Integrity',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        final data = booking.data()!;

        // Check data types
        expect(data['fare'], isA<num>());
        expect(data['status'], isA<String>());
        expect(data['pickup'], isA<Map>());
      },
    );
  }

  Future<void> _testTimestampHandling(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Timestamps are handled correctly',
      category: 'Database/Integrity',
      testFunction: () async {
        final user = await mockFirebase.firestore
            .collection('users')
            .doc('test_user_001')
            .get();

        final createdAt = user.data()!['createdAt'];
        expect(createdAt, isNotNull);
      },
    );
  }

  // ==========================================
  // EDGE CASE TESTS
  // ==========================================

  Future<void> _testEmptyCollectionQuery(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Empty collection query returns empty list',
      category: 'Database/EdgeCases',
      testFunction: () async {
        final results = await mockFirebase.firestore
            .collection('non_existent_collection')
            .get();

        expect(results.docs.isEmpty, true);
      },
    );
  }

  Future<void> _testNonExistentDocument(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Non-existent document returns null',
      category: 'Database/EdgeCases',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('users')
            .doc('non_existent_id')
            .get();

        expect(doc.exists, false);
      },
    );
  }

  Future<void> _testLargeDataHandling(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Large data can be stored and retrieved',
      category: 'Database/EdgeCases',
      testFunction: () async {
        // Create document with large text
        final largeText = 'A' * 10000; // 10KB of text

        await mockFirebase.firestore
            .collection('test_crud')
            .doc('large_data')
            .set({
          'largeField': largeText,
        });

        final doc =
            await mockFirebase.firestore.collection('test_crud').doc('large_data').get();

        expect(doc.exists, true);
        expect((doc.data()!['largeField'] as String).length, 10000);
      },
    );
  }

  // ==========================================
  // INDEX TESTS
  // ==========================================

  Future<void> _testCompositeQueries(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Composite queries work (index required)',
      category: 'Database/Index',
      testFunction: () async {
        // Query that would require composite index in production
        final results = await mockFirebase.firestore
            .collection('bookings')
            .where('userId', isEqualTo: 'test_user_001')
            .where('status', isEqualTo: 'completed')
            .get();

        expect(results.docs.isNotEmpty, true);
      },
    );
  }
}
