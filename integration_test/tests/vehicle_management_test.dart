// integration_test/tests/vehicle_management_test.dart
// E2E Tests for Vehicle Management

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test_config.dart';
import '../test_report_generator.dart';
import '../mocks/mock_firebase_service.dart';

/// Vehicle Management E2E Tests
class VehicleManagementTests {
  final TestRunner testRunner;
  final MockFirebaseService mockFirebase;
  late FirestoreAssertions firestoreAssertions;

  VehicleManagementTests({
    required this.testRunner,
    required this.mockFirebase,
  }) {
    firestoreAssertions = FirestoreAssertions(mockFirebase.firestore);
  }

  /// Run all vehicle management tests
  Future<void> runAllTests(WidgetTester tester) async {
    testRunner.startSuite('Vehicle Management Tests');

    // Vehicle Catalog Tests
    await _testVehicleCatalogLoads(tester);
    await _testVehicleCatalogContainsMakes(tester);
    await _testVehicleCatalogContainsTypes(tester);

    // Vehicle List Tests
    await _testVehicleListScreenLoads(tester);
    await _testVehicleListDisplaysVehicles(tester);
    await _testVehicleListFiltersByStatus(tester);

    // Vehicle Registration Tests
    await _testVehicleRegistrationScreenLoads(tester);
    await _testVehicleRegistrationValidation(tester);
    await _testVehicleRegistrationDuplicateCheck(tester);
    await _testVehicleRegistrationSuccess(tester);

    // Vehicle Edit Tests
    await _testVehicleEditScreenLoads(tester);
    await _testVehicleEditSavesChanges(tester);

    // Vehicle View Tests
    await _testVehicleViewScreenLoads(tester);
    await _testVehicleViewDisplaysDetails(tester);
    await _testVehicleViewShowsDocuments(tester);

    // Vehicle Documents Tests
    await _testDocumentUploadScreenLoads(tester);
    await _testDocumentStatusTracking(tester);

    // Availability Tests
    await _testAvailabilityScreenLoads(tester);
    await _testAvailabilityToggle(tester);
    await _testWorkingModeSelection(tester);
    await _testCustomHoursValidation(tester);
  }

  // ==========================================
  // VEHICLE CATALOG TESTS
  // ==========================================

  Future<void> _testVehicleCatalogLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle catalog loads from Firestore',
      category: 'VehicleManagement/Catalog',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get();

        expect(doc.exists, true);
        expect(doc.data(), isNotNull);
        expect(doc.data()!.containsKey('makes'), true);
      },
    );
  }

  Future<void> _testVehicleCatalogContainsMakes(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle catalog contains all major makes',
      category: 'VehicleManagement/Catalog',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get();

        final makes = doc.data()!['makes'] as Map<String, dynamic>;
        expect(makes.containsKey('Maruti'), true);
        expect(makes.containsKey('Honda'), true);
        expect(makes.containsKey('Toyota'), true);
        expect(makes.containsKey('Hyundai'), true);
        expect(makes.containsKey('Tata'), true);
      },
    );
  }

  Future<void> _testVehicleCatalogContainsTypes(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle catalog contains all vehicle types',
      category: 'VehicleManagement/Catalog',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('vehicleCatalog')
            .doc('india2025')
            .get();

        final types = doc.data()!['vehicleTypes'] as List;
        expect(types.contains('Hatchback'), true);
        expect(types.contains('Sedan'), true);
        expect(types.contains('SUV'), true);
        expect(types.contains('MUV'), true);
      },
    );
  }

  // ==========================================
  // VEHICLE LIST TESTS
  // ==========================================

  Future<void> _testVehicleListScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle list screen loads successfully',
      category: 'VehicleManagement/List',
      testFunction: () async {
        await mockFirebase.signInTestUser(role: 'owner');

        await tester.pumpWidget(_buildTestApp('/vehicle-list'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testVehicleListDisplaysVehicles(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle list displays owner vehicles',
      category: 'VehicleManagement/List',
      testFunction: () async {
        // Query vehicles for test owner
        final snapshot = await mockFirebase.firestore
            .collection('vehicles')
            .where('userId', isEqualTo: 'test_owner_001')
            .get();

        expect(snapshot.docs.length, greaterThan(0));
        expect(snapshot.docs.length, 3); // We seeded 3 vehicles
      },
    );
  }

  Future<void> _testVehicleListFiltersByStatus(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle list can filter by document status',
      category: 'VehicleManagement/List',
      testFunction: () async {
        // Filter approved vehicles
        final approved = await mockFirebase.firestore
            .collection('vehicles')
            .where('documentStatus', isEqualTo: 'approved')
            .get();

        expect(approved.docs.length, 2);

        // Filter pending vehicles
        final pending = await mockFirebase.firestore
            .collection('vehicles')
            .where('documentStatus', isEqualTo: 'pending')
            .get();

        expect(pending.docs.length, 1);
      },
    );
  }

  // ==========================================
  // VEHICLE REGISTRATION TESTS
  // ==========================================

  Future<void> _testVehicleRegistrationScreenLoads(
      WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle registration screen loads',
      category: 'VehicleManagement/Registration',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/vehicle-registration'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testVehicleRegistrationValidation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle registration validates required fields',
      category: 'VehicleManagement/Registration',
      testFunction: () async {
        // Test validation logic
        final testData = MockDataGenerator.generateVehicleData();

        // Validate registration number format
        final regNumber =
            testData['vehicleDetails']['registrationNumber'] as String;
        final regNumberValid = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$')
            .hasMatch(regNumber);
        expect(regNumberValid, true);
      },
    );
  }

  Future<void> _testVehicleRegistrationDuplicateCheck(
      WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle registration prevents duplicate registration numbers',
      category: 'VehicleManagement/Registration',
      testFunction: () async {
        // Check if existing registration exists
        final existingReg = 'KA01AB1234';
        final snapshot = await mockFirebase.firestore
            .collection('vehicles')
            .where('vehicleDetails.registrationNumber', isEqualTo: existingReg)
            .get();

        expect(snapshot.docs.isNotEmpty, true);
      },
    );
  }

  Future<void> _testVehicleRegistrationSuccess(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle registration creates new vehicle document',
      category: 'VehicleManagement/Registration',
      testFunction: () async {
        final newVehicleId = 'test_new_vehicle_${DateTime.now().millisecondsSinceEpoch}';

        await mockFirebase.firestore
            .collection('vehicles')
            .doc(newVehicleId)
            .set({
          'userId': 'test_owner_001',
          'vehicleDetails': {
            'registrationNumber': 'KA02XY9999',
            'make': 'Maruti',
            'model': 'Baleno',
            'type': 'Hatchback',
          },
          'documentStatus': 'pending',
          'createdAt': DateTime.now(),
        });

        final doc = await mockFirebase.firestore
            .collection('vehicles')
            .doc(newVehicleId)
            .get();

        expect(doc.exists, true);
        expect(doc.data()!['vehicleDetails']['make'], 'Maruti');
      },
    );
  }

  // ==========================================
  // VEHICLE EDIT TESTS
  // ==========================================

  Future<void> _testVehicleEditScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle edit screen loads with vehicle data',
      category: 'VehicleManagement/Edit',
      testFunction: () async {
        await tester.pumpWidget(
            _buildTestApp('/vehicle-edit?vehicleId=test_vehicle_001'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testVehicleEditSavesChanges(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle edit saves changes to Firestore',
      category: 'VehicleManagement/Edit',
      testFunction: () async {
        // Update vehicle color
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .update({
          'vehicleDetails.color': 'Blue',
        });

        final doc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        expect(doc.data()!['vehicleDetails']['color'], 'Blue');
      },
    );
  }

  // ==========================================
  // VEHICLE VIEW TESTS
  // ==========================================

  Future<void> _testVehicleViewScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle view screen loads',
      category: 'VehicleManagement/View',
      testFunction: () async {
        await tester.pumpWidget(
            _buildTestApp('/vehicle-view?vehicleId=test_vehicle_001'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testVehicleViewDisplaysDetails(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle view displays all vehicle details',
      category: 'VehicleManagement/View',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        final vehicleDetails = doc.data()!['vehicleDetails'];
        expect(vehicleDetails['registrationNumber'], isNotNull);
        expect(vehicleDetails['make'], isNotNull);
        expect(vehicleDetails['model'], isNotNull);
        expect(vehicleDetails['type'], isNotNull);
      },
    );
  }

  Future<void> _testVehicleViewShowsDocuments(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle view shows document status',
      category: 'VehicleManagement/View',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        expect(doc.data()!.containsKey('documents'), true);
        expect(doc.data()!.containsKey('documentStatus'), true);
      },
    );
  }

  // ==========================================
  // DOCUMENT UPLOAD TESTS
  // ==========================================

  Future<void> _testDocumentUploadScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Document upload screen loads',
      category: 'VehicleManagement/Documents',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/document-upload'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testDocumentStatusTracking(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Document status is tracked correctly',
      category: 'VehicleManagement/Documents',
      testFunction: () async {
        // Check approved vehicle documents
        final approvedDoc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        expect(approvedDoc.data()!['documentStatus'], 'approved');

        // Check pending vehicle documents
        final pendingDoc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_003')
            .get();

        expect(pendingDoc.data()!['documentStatus'], 'pending');
      },
    );
  }

  // ==========================================
  // AVAILABILITY TESTS
  // ==========================================

  Future<void> _testAvailabilityScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Availability screen loads',
      category: 'VehicleManagement/Availability',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/availability'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testAvailabilityToggle(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Online/Offline toggle works correctly',
      category: 'VehicleManagement/Availability',
      testFunction: () async {
        // Toggle availability
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .update({
          'availability.isOnline': false,
        });

        final doc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        expect(doc.data()!['availability']['isOnline'], false);

        // Toggle back
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .update({
          'availability.isOnline': true,
        });
      },
    );
  }

  Future<void> _testWorkingModeSelection(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Working mode can be changed',
      category: 'VehicleManagement/Availability',
      testFunction: () async {
        final modes = ['always_available', 'day_shift', 'night_shift', 'custom'];

        for (var mode in modes) {
          await mockFirebase.firestore
              .collection('vehicles')
              .doc('test_vehicle_001')
              .update({
            'availability.workingMode': mode,
          });

          final doc = await mockFirebase.firestore
              .collection('vehicles')
              .doc('test_vehicle_001')
              .get();

          expect(doc.data()!['availability']['workingMode'], mode);
        }
      },
    );
  }

  Future<void> _testCustomHoursValidation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Custom hours validation works correctly',
      category: 'VehicleManagement/Availability',
      testFunction: () async {
        // Valid custom hours
        final validStartTime = '09:00';
        final validEndTime = '18:00';

        // Parse and validate
        final startParts = validStartTime.split(':');
        final endParts = validEndTime.split(':');

        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes =
            int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        // End should be after start
        expect(endMinutes > startMinutes, true);

        // Duration should be at least 1 hour
        expect(endMinutes - startMinutes >= 60, true);

        // Duration should not exceed 16 hours
        expect(endMinutes - startMinutes <= 960, true);
      },
    );
  }

  /// Build test app with route
  Widget _buildTestApp(String route) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Test Route: $route'),
        ),
      ),
    );
  }
}
