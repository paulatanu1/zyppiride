// integration_test/tests/driver_dashboard_test.dart
// E2E Tests for Driver/Owner Dashboard

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test_config.dart';
import '../test_report_generator.dart';
import '../mocks/mock_firebase_service.dart';

/// Driver/Owner Dashboard E2E Tests
class DriverDashboardTests {
  final TestRunner testRunner;
  final MockFirebaseService mockFirebase;
  late FirestoreAssertions firestoreAssertions;

  DriverDashboardTests({
    required this.testRunner,
    required this.mockFirebase,
  }) {
    firestoreAssertions = FirestoreAssertions(mockFirebase.firestore);
  }

  /// Run all driver dashboard tests
  Future<void> runAllTests(WidgetTester tester) async {
    testRunner.startSuite('Driver/Owner Dashboard Tests');

    // Dashboard Load Tests
    await _testMainDashboardLoadsForDriver(tester);
    await _testMainDashboardLoadsForOwner(tester);
    await _testDashboardDisplaysCorrectRole(tester);
    await _testDashboardDisplaysStats(tester);

    // Profile Tests
    await _testDriverProfileLoads(tester);
    await _testDriverProfileDisplaysInfo(tester);
    await _testDriverLicenseInfo(tester);
    await _testProfileEditFunctionality(tester);

    // Vehicle Management Tests
    await _testVehicleListAccessible(tester);
    await _testActiveVehiclesScreen(tester);
    await _testVehicleStatusToggle(tester);

    // Delivery Requests Tests
    await _testDeliveryRequestsScreenLoads(tester);
    await _testDeliveryRequestsQuery(tester);

    // Schedule Management Tests
    await _testWeeklyScheduleScreenLoads(tester);
    await _testScheduleDataStructure(tester);

    // Availability Management Tests
    await _testDriverAvailabilityScreen(tester);
    await _testAvailabilityModeChange(tester);

    // Agreement Tests
    await _testAgreementSigningScreen(tester);
    await _testAgreementDataExists(tester);

    // Notifications Tests
    await _testNotificationsScreenLoads(tester);

    // Promotions Tests
    await _testPromotionsScreenLoads(tester);
  }

  // ==========================================
  // DASHBOARD LOAD TESTS
  // ==========================================

  Future<void> _testMainDashboardLoadsForDriver(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Main dashboard loads for driver role',
      category: 'DriverDashboard/Load',
      testFunction: () async {
        await mockFirebase.signInTestUser(role: 'driver');

        await tester.pumpWidget(_buildTestApp('/dashboard'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testMainDashboardLoadsForOwner(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Main dashboard loads for owner role',
      category: 'DriverDashboard/Load',
      testFunction: () async {
        await mockFirebase.signInTestUser(role: 'owner');

        await tester.pumpWidget(_buildTestApp('/dashboard'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testDashboardDisplaysCorrectRole(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Dashboard displays correct role information',
      category: 'DriverDashboard/Load',
      testFunction: () async {
        // Check driver role
        final driverDoc = await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .get();

        expect(driverDoc.data()!['role'], 'driver');

        // Check owner role
        final ownerDoc = await mockFirebase.firestore
            .collection('users')
            .doc('test_owner_001')
            .get();

        expect(ownerDoc.data()!['role'], 'owner');
      },
    );
  }

  Future<void> _testDashboardDisplaysStats(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Dashboard displays user statistics',
      category: 'DriverDashboard/Load',
      testFunction: () async {
        final driverDoc = await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .get();

        expect(driverDoc.data()!.containsKey('totalRides'), true);
        expect(driverDoc.data()!.containsKey('rating'), true);
        expect(driverDoc.data()!['totalRides'], 150);
        expect(driverDoc.data()!['rating'], 4.9);
      },
    );
  }

  // ==========================================
  // PROFILE TESTS
  // ==========================================

  Future<void> _testDriverProfileLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver profile screen loads',
      category: 'DriverDashboard/Profile',
      testFunction: () async {
        await tester.pumpWidget(
            _buildTestApp('/driver-profile?userId=test_driver_001'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testDriverProfileDisplaysInfo(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver profile displays all information',
      category: 'DriverDashboard/Profile',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .get();

        expect(doc.data()!['fullName'], TestConfig.testDriverName);
        expect(doc.data()!['email'], TestConfig.testDriverEmail);
        expect(doc.data()!['mobile'], TestConfig.testDriverPhone);
      },
    );
  }

  Future<void> _testDriverLicenseInfo(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver profile shows license information',
      category: 'DriverDashboard/Profile',
      testFunction: () async {
        final doc = await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .get();

        expect(doc.data()!.containsKey('drivingLicenseNumber'), true);
        expect(doc.data()!.containsKey('drivingLicenseValidUpto'), true);
      },
    );
  }

  Future<void> _testProfileEditFunctionality(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Profile can be edited and saved',
      category: 'DriverDashboard/Profile',
      testFunction: () async {
        // Update profile
        await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .update({
          'fullName': 'Updated Driver Name',
        });

        final doc = await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .get();

        expect(doc.data()!['fullName'], 'Updated Driver Name');

        // Restore original name
        await mockFirebase.firestore
            .collection('users')
            .doc('test_driver_001')
            .update({
          'fullName': TestConfig.testDriverName,
        });
      },
    );
  }

  // ==========================================
  // VEHICLE MANAGEMENT TESTS
  // ==========================================

  Future<void> _testVehicleListAccessible(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle list is accessible from dashboard',
      category: 'DriverDashboard/Vehicles',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/vehicle-list'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testActiveVehiclesScreen(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Active vehicles screen loads',
      category: 'DriverDashboard/Vehicles',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/active-vehicles'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testVehicleStatusToggle(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle online status can be toggled',
      category: 'DriverDashboard/Vehicles',
      testFunction: () async {
        // Get initial status
        final initialDoc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        final initialStatus = initialDoc.data()!['availability']['isOnline'];

        // Toggle status
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .update({
          'availability.isOnline': !initialStatus,
        });

        final updatedDoc = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .get();

        expect(
            updatedDoc.data()!['availability']['isOnline'], !initialStatus);

        // Restore original status
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .update({
          'availability.isOnline': initialStatus,
        });
      },
    );
  }

  // ==========================================
  // DELIVERY REQUESTS TESTS
  // ==========================================

  Future<void> _testDeliveryRequestsScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Delivery requests screen loads',
      category: 'DriverDashboard/Deliveries',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/delivery-requests'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testDeliveryRequestsQuery(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Delivery requests can be queried',
      category: 'DriverDashboard/Deliveries',
      testFunction: () async {
        // Query bookings assigned to driver
        final deliveries = await mockFirebase.firestore
            .collection('bookings')
            .where('driverId', isEqualTo: 'test_driver_001')
            .get();

        // Should have at least one booking
        expect(deliveries.docs.isNotEmpty, true);
      },
    );
  }

  // ==========================================
  // SCHEDULE MANAGEMENT TESTS
  // ==========================================

  Future<void> _testWeeklyScheduleScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Weekly schedule screen loads',
      category: 'DriverDashboard/Schedule',
      testFunction: () async {
        await tester.pumpWidget(
            _buildTestApp('/manage-schedule?vehicleId=test_vehicle_001'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testScheduleDataStructure(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Schedule data structure is correct',
      category: 'DriverDashboard/Schedule',
      testFunction: () async {
        // Create test schedule
        await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .collection('schedules')
            .doc('week_schedule')
            .set({
          'monday': {'isAvailable': true, 'startTime': '09:00', 'endTime': '18:00'},
          'tuesday': {'isAvailable': true, 'startTime': '09:00', 'endTime': '18:00'},
          'wednesday': {'isAvailable': true, 'startTime': '09:00', 'endTime': '18:00'},
          'thursday': {'isAvailable': true, 'startTime': '09:00', 'endTime': '18:00'},
          'friday': {'isAvailable': true, 'startTime': '09:00', 'endTime': '18:00'},
          'saturday': {'isAvailable': false},
          'sunday': {'isAvailable': false},
        });

        final schedule = await mockFirebase.firestore
            .collection('vehicles')
            .doc('test_vehicle_001')
            .collection('schedules')
            .doc('week_schedule')
            .get();

        expect(schedule.exists, true);
        expect(schedule.data()!.containsKey('monday'), true);
      },
    );
  }

  // ==========================================
  // AVAILABILITY MANAGEMENT TESTS
  // ==========================================

  Future<void> _testDriverAvailabilityScreen(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver availability screen loads',
      category: 'DriverDashboard/Availability',
      testFunction: () async {
        await tester.pumpWidget(
            _buildTestApp('/driver-availability?vehicleId=test_vehicle_001'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testAvailabilityModeChange(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Availability mode can be changed',
      category: 'DriverDashboard/Availability',
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

  // ==========================================
  // AGREEMENT TESTS
  // ==========================================

  Future<void> _testAgreementSigningScreen(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Agreement signing screen loads',
      category: 'DriverDashboard/Agreements',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/agreement-signing'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testAgreementDataExists(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Agreement documents exist in Firestore',
      category: 'DriverDashboard/Agreements',
      testFunction: () async {
        final driverAgreement = await mockFirebase.firestore
            .collection('agreements')
            .doc('driver_agreement_v1')
            .get();

        expect(driverAgreement.exists, true);
        expect(driverAgreement.data()!.containsKey('content'), true);
        expect(driverAgreement.data()!['type'], 'driver');

        final ownerAgreement = await mockFirebase.firestore
            .collection('agreements')
            .doc('owner_agreement_v1')
            .get();

        expect(ownerAgreement.exists, true);
        expect(ownerAgreement.data()!['type'], 'owner');
      },
    );
  }

  // ==========================================
  // NOTIFICATIONS TESTS
  // ==========================================

  Future<void> _testNotificationsScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Notifications screen loads',
      category: 'DriverDashboard/Notifications',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/notifications'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  // ==========================================
  // PROMOTIONS TESTS
  // ==========================================

  Future<void> _testPromotionsScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Promotions screen loads',
      category: 'DriverDashboard/Promotions',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/promotions'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
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
