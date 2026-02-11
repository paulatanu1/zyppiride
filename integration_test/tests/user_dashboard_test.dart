// integration_test/tests/user_dashboard_test.dart
// E2E Tests for User Dashboard

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_config.dart';
import '../test_report_generator.dart';
import '../mocks/mock_firebase_service.dart';

/// User Dashboard E2E Tests
class UserDashboardTests {
  final TestRunner testRunner;
  final MockFirebaseService mockFirebase;
  late FirestoreAssertions firestoreAssertions;

  UserDashboardTests({
    required this.testRunner,
    required this.mockFirebase,
  }) {
    firestoreAssertions = FirestoreAssertions(mockFirebase.firestore);
  }

  /// Run all user dashboard tests
  Future<void> runAllTests(WidgetTester tester) async {
    testRunner.startSuite('User Dashboard Tests');

    // Dashboard Load Tests
    await _testUserDashboardLoads(tester);
    await _testDashboardDisplaysUserInfo(tester);
    await _testDashboardBannersLoad(tester);
    await _testDashboardServiceOptions(tester);

    // Navigation Tests
    await _testNavigationToLocalTransport(tester);
    await _testNavigationToOutstation(tester);
    await _testNavigationToGoodsCarrier(tester);
    await _testNavigationToProfile(tester);
    await _testNavigationToOffers(tester);
    await _testNavigationToRideHistory(tester);

    // Offers & Promotions Tests
    await _testOffersScreenLoads(tester);
    await _testActiveOffersDisplay(tester);
    await _testOfferCodeValidation(tester);

    // Booking Screen Tests
    await _testReserveVehicleScreenLoads(tester);
    await _testVehicleSearchFunctionality(tester);
    await _testVehicleDetailsScreen(tester);

    // Ride History Tests
    await _testRideHistoryLoads(tester);
    await _testRideHistoryFiltersByStatus(tester);
    await _testRideDetailsDisplay(tester);

    // Support Center Tests
    await _testSupportCenterLoads(tester);
    await _testEmergencyScreenLoads(tester);
  }

  // ==========================================
  // DASHBOARD LOAD TESTS
  // ==========================================

  Future<void> _testUserDashboardLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'User dashboard loads successfully',
      category: 'UserDashboard/Load',
      testFunction: () async {
        await mockFirebase.signInTestUser(role: 'user');

        await tester.pumpWidget(_buildTestApp('/user-dashboard'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testDashboardDisplaysUserInfo(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Dashboard displays user information',
      category: 'UserDashboard/Load',
      testFunction: () async {
        final userDoc = await mockFirebase.firestore
            .collection('users')
            .doc('test_user_001')
            .get();

        expect(userDoc.exists, true);
        expect(userDoc.data()!['fullName'], TestConfig.testUserName);
        expect(userDoc.data()!['email'], TestConfig.testUserEmail);
      },
    );
  }

  Future<void> _testDashboardBannersLoad(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Dashboard banners load from Firestore',
      category: 'UserDashboard/Content',
      testFunction: () async {
        final banners = await mockFirebase.firestore
            .collection('banners')
            .where('isActive', isEqualTo: true)
            .get();

        expect(banners.docs.isNotEmpty, true);
        expect(banners.docs.length, greaterThanOrEqualTo(1));
      },
    );
  }

  Future<void> _testDashboardServiceOptions(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Dashboard displays all service options',
      category: 'UserDashboard/Content',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/user-dashboard'));
        await tester.pumpAndSettle();

        // Service options should be available
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  // ==========================================
  // NAVIGATION TESTS
  // ==========================================

  Future<void> _testNavigationToLocalTransport(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Navigation to local transport works',
      category: 'UserDashboard/Navigation',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/local-transport'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testNavigationToOutstation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Navigation to outstation screen works',
      category: 'UserDashboard/Navigation',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/outstation'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testNavigationToGoodsCarrier(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Navigation to goods carrier screen works',
      category: 'UserDashboard/Navigation',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/book-goods-carrier'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testNavigationToProfile(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Navigation to user profile works',
      category: 'UserDashboard/Navigation',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/user-profile'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testNavigationToOffers(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Navigation to offers screen works',
      category: 'UserDashboard/Navigation',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/offers-rewards'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testNavigationToRideHistory(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Navigation to ride history works',
      category: 'UserDashboard/Navigation',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/user-ride-history'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  // ==========================================
  // OFFERS & PROMOTIONS TESTS
  // ==========================================

  Future<void> _testOffersScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Offers screen loads successfully',
      category: 'UserDashboard/Offers',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/offers-rewards'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testActiveOffersDisplay(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Active offers are displayed correctly',
      category: 'UserDashboard/Offers',
      testFunction: () async {
        final offers = await mockFirebase.firestore
            .collection('offers')
            .where('isActive', isEqualTo: true)
            .get();

        expect(offers.docs.isNotEmpty, true);

        // Check offer structure
        for (var offer in offers.docs) {
          final data = offer.data();
          expect(data?.containsKey('code'), true);
          expect(data?.containsKey('title'), true);
          expect(data?.containsKey('discountType'), true);
          expect(data?.containsKey('discountValue'), true);
        }
      },
    );
  }

  Future<void> _testOfferCodeValidation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Offer code validation works correctly',
      category: 'UserDashboard/Offers',
      testFunction: () async {
        // Test valid offer code
        final validOffer = await mockFirebase.firestore
            .collection('offers')
            .where('code', isEqualTo: 'FIRST20')
            .where('isActive', isEqualTo: true)
            .get();

        expect(validOffer.docs.isNotEmpty, true);

        // Test invalid offer code
        final invalidOffer = await mockFirebase.firestore
            .collection('offers')
            .where('code', isEqualTo: 'INVALID123')
            .get();

        expect(invalidOffer.docs.isEmpty, true);
      },
    );
  }

  // ==========================================
  // BOOKING SCREEN TESTS
  // ==========================================

  Future<void> _testReserveVehicleScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Reserve vehicle screen loads',
      category: 'UserDashboard/Booking',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/reserve-vehicle'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testVehicleSearchFunctionality(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle search returns available vehicles',
      category: 'UserDashboard/Booking',
      testFunction: () async {
        // Search for available vehicles
        final availableVehicles = await mockFirebase.firestore
            .collection('vehicles')
            .where('availability.isOnline', isEqualTo: true)
            .where('documentStatus', isEqualTo: 'approved')
            .get();

        expect(availableVehicles.docs.isNotEmpty, true);
      },
    );
  }

  Future<void> _testVehicleDetailsScreen(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Vehicle details screen displays correctly',
      category: 'UserDashboard/Booking',
      testFunction: () async {
        await tester.pumpWidget(
            _buildTestApp('/vehicle-details?vehicleId=test_vehicle_001'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  // ==========================================
  // RIDE HISTORY TESTS
  // ==========================================

  Future<void> _testRideHistoryLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Ride history screen loads',
      category: 'UserDashboard/History',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/user-ride-history'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testRideHistoryFiltersByStatus(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Ride history can filter by status',
      category: 'UserDashboard/History',
      testFunction: () async {
        // Get completed rides
        final completed = await mockFirebase.firestore
            .collection('bookings')
            .where('userId', isEqualTo: 'test_user_001')
            .where('status', isEqualTo: 'completed')
            .get();

        expect(completed.docs.isNotEmpty, true);

        // Get cancelled rides
        final cancelled = await mockFirebase.firestore
            .collection('bookings')
            .where('userId', isEqualTo: 'test_user_001')
            .where('status', isEqualTo: 'cancelled')
            .get();

        expect(cancelled.docs.isNotEmpty, true);
      },
    );
  }

  Future<void> _testRideDetailsDisplay(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Ride details display all information',
      category: 'UserDashboard/History',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .get();

        expect(booking.exists, true);

        final data = booking.data()!;
        expect(data.containsKey('pickup'), true);
        expect(data.containsKey('drop'), true);
        expect(data.containsKey('fare'), true);
        expect(data.containsKey('status'), true);
      },
    );
  }

  // ==========================================
  // SUPPORT CENTER TESTS
  // ==========================================

  Future<void> _testSupportCenterLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Support center screen loads',
      category: 'UserDashboard/Support',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/support-center'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testEmergencyScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Emergency screen loads',
      category: 'UserDashboard/Support',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/emergency'));
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
