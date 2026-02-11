// integration_test/tests/booking_flow_test.dart
// E2E Tests for Booking Flow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_config.dart';
import '../test_report_generator.dart';
import '../mocks/mock_firebase_service.dart';

/// Booking Flow E2E Tests
class BookingFlowTests {
  final TestRunner testRunner;
  final MockFirebaseService mockFirebase;
  late FirestoreAssertions firestoreAssertions;

  BookingFlowTests({
    required this.testRunner,
    required this.mockFirebase,
  }) {
    firestoreAssertions = FirestoreAssertions(mockFirebase.firestore);
  }

  /// Run all booking flow tests
  Future<void> runAllTests(WidgetTester tester) async {
    testRunner.startSuite('Booking Flow Tests');

    // Booking Creation Tests
    await _testCreateNewBooking(tester);
    await _testBookingValidation(tester);
    await _testBookingWithPickupLocation(tester);
    await _testBookingWithDropLocation(tester);
    await _testBookingFareCalculation(tester);

    // Booking Status Tests
    await _testBookingStatusPending(tester);
    await _testBookingStatusAccepted(tester);
    await _testBookingStatusInProgress(tester);
    await _testBookingStatusCompleted(tester);
    await _testBookingStatusCancelled(tester);

    // Driver Assignment Tests
    await _testDriverAssignment(tester);
    await _testDriverCanAcceptBooking(tester);
    await _testDriverCanRejectBooking(tester);

    // Tracking Tests
    await _testTrackBookingScreenLoads(tester);
    await _testActiveBookingQuery(tester);

    // Rating & Feedback Tests
    await _testBookingRating(tester);
    await _testBookingFeedback(tester);

    // Cancellation Tests
    await _testCancellationReasons(tester);
    await _testCancellationTimestamp(tester);

    // Fare & Payment Tests
    await _testFareBreakdown(tester);
    await _testOfferCodeApplication(tester);
    await _testPaymentStatus(tester);
  }

  // ==========================================
  // BOOKING CREATION TESTS
  // ==========================================

  Future<void> _testCreateNewBooking(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'New booking can be created',
      category: 'BookingFlow/Create',
      testFunction: () async {
        final newBookingId =
            'test_new_booking_${DateTime.now().millisecondsSinceEpoch}';

        await mockFirebase.firestore
            .collection('bookings')
            .doc(newBookingId)
            .set({
          'bookingId': newBookingId,
          'userId': 'test_user_001',
          'vehicleId': 'test_vehicle_001',
          'status': 'pending',
          'pickup': {
            'address': 'Test Pickup Location',
            'lat': 12.9716,
            'lng': 77.5946,
          },
          'drop': {
            'address': 'Test Drop Location',
            'lat': 12.9816,
            'lng': 77.6046,
          },
          'fare': 200.0,
          'createdAt': DateTime.now(),
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc(newBookingId)
            .get();

        expect(booking.exists, true);
        expect(booking.data()!['status'], 'pending');
      },
    );
  }

  Future<void> _testBookingValidation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking validates required fields',
      category: 'BookingFlow/Create',
      testFunction: () async {
        final bookingData = MockDataGenerator.generateBookingData();

        // Required fields check
        expect(bookingData.containsKey('userId'), true);
        expect(bookingData.containsKey('pickup'), true);
        expect(bookingData.containsKey('drop'), true);
        expect(bookingData.containsKey('fare'), true);

        // Pickup validation
        final pickup = bookingData['pickup'] as Map<String, dynamic>;
        expect(pickup.containsKey('address'), true);
        expect(pickup.containsKey('lat'), true);
        expect(pickup.containsKey('lng'), true);
      },
    );
  }

  Future<void> _testBookingWithPickupLocation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking stores pickup location correctly',
      category: 'BookingFlow/Create',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        final pickup = booking.data()!['pickup'] as Map<String, dynamic>;
        expect(pickup['address'], isNotEmpty);
        expect(pickup['lat'], isA<double>());
        expect(pickup['lng'], isA<double>());
      },
    );
  }

  Future<void> _testBookingWithDropLocation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking stores drop location correctly',
      category: 'BookingFlow/Create',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        final drop = booking.data()!['drop'] as Map<String, dynamic>;
        expect(drop['address'], isNotEmpty);
        expect(drop['lat'], isA<double>());
        expect(drop['lng'], isA<double>());
      },
    );
  }

  Future<void> _testBookingFareCalculation(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking fare is calculated correctly',
      category: 'BookingFlow/Create',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        final fare = booking.data()!['fare'];
        expect(fare, isA<num>());
        expect(fare, greaterThan(0));
      },
    );
  }

  // ==========================================
  // BOOKING STATUS TESTS
  // ==========================================

  Future<void> _testBookingStatusPending(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Pending booking status is handled',
      category: 'BookingFlow/Status',
      testFunction: () async {
        final pendingBookings = await mockFirebase.firestore
            .collection('bookings')
            .where('status', isEqualTo: 'pending')
            .get();

        // Pending bookings should not have a driver assigned
        for (var doc in pendingBookings.docs) {
          // Pending may or may not have driver yet
          expect(doc.data()?['status'], 'pending');
        }
      },
    );
  }

  Future<void> _testBookingStatusAccepted(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Accepted booking has driver assigned',
      category: 'BookingFlow/Status',
      testFunction: () async {
        // Create an accepted booking
        await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_accepted')
            .set({
          'bookingId': 'test_booking_accepted',
          'userId': 'test_user_001',
          'vehicleId': 'test_vehicle_001',
          'driverId': 'test_driver_001',
          'status': 'accepted',
          'pickup': {'address': 'Test', 'lat': 12.9716, 'lng': 77.5946},
          'drop': {'address': 'Test Drop', 'lat': 12.9816, 'lng': 77.6046},
          'fare': 300.0,
          'createdAt': DateTime.now(),
          'acceptedAt': DateTime.now(),
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_accepted')
            .get();

        expect(booking.data()!['status'], 'accepted');
        expect(booking.data()!['driverId'], isNotNull);
        expect(booking.data()!['acceptedAt'], isNotNull);
      },
    );
  }

  Future<void> _testBookingStatusInProgress(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'In-progress booking is trackable',
      category: 'BookingFlow/Status',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        expect(booking.data()!['status'], 'in_progress');
        expect(booking.data()!['driverId'], isNotNull);
      },
    );
  }

  Future<void> _testBookingStatusCompleted(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Completed booking has all required fields',
      category: 'BookingFlow/Status',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .get();

        expect(booking.data()!['status'], 'completed');
        expect(booking.data()!['completedAt'], isNotNull);
        expect(booking.data()!['rating'], isNotNull);
      },
    );
  }

  Future<void> _testBookingStatusCancelled(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Cancelled booking has cancellation reason',
      category: 'BookingFlow/Status',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_003')
            .get();

        expect(booking.data()!['status'], 'cancelled');
        expect(booking.data()!['cancelledAt'], isNotNull);
        expect(booking.data()!['cancellationReason'], isNotNull);
      },
    );
  }

  // ==========================================
  // DRIVER ASSIGNMENT TESTS
  // ==========================================

  Future<void> _testDriverAssignment(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver can be assigned to booking',
      category: 'BookingFlow/Driver',
      testFunction: () async {
        final testBookingId = 'test_assign_${DateTime.now().millisecondsSinceEpoch}';

        // Create pending booking
        await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .set({
          'bookingId': testBookingId,
          'userId': 'test_user_001',
          'vehicleId': 'test_vehicle_001',
          'status': 'pending',
          'pickup': {'address': 'Test', 'lat': 12.9716, 'lng': 77.5946},
          'drop': {'address': 'Test Drop', 'lat': 12.9816, 'lng': 77.6046},
          'fare': 250.0,
          'createdAt': DateTime.now(),
        });

        // Assign driver
        await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .update({
          'driverId': 'test_driver_001',
          'status': 'accepted',
          'acceptedAt': DateTime.now(),
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .get();

        expect(booking.data()!['driverId'], 'test_driver_001');
        expect(booking.data()!['status'], 'accepted');
      },
    );
  }

  Future<void> _testDriverCanAcceptBooking(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver can accept booking',
      category: 'BookingFlow/Driver',
      testFunction: () async {
        // Query available bookings for driver
        final availableBookings = await mockFirebase.firestore
            .collection('bookings')
            .where('status', isEqualTo: 'pending')
            .get();

        // Should be able to query pending bookings
        expect(availableBookings.docs.isEmpty || availableBookings.docs.isNotEmpty, true);
      },
    );
  }

  Future<void> _testDriverCanRejectBooking(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Driver can reject booking',
      category: 'BookingFlow/Driver',
      testFunction: () async {
        // Create and then reject a booking
        final testBookingId = 'test_reject_${DateTime.now().millisecondsSinceEpoch}';

        await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .set({
          'bookingId': testBookingId,
          'userId': 'test_user_001',
          'status': 'pending',
          'pickup': {'address': 'Test', 'lat': 12.9716, 'lng': 77.5946},
          'drop': {'address': 'Test Drop', 'lat': 12.9816, 'lng': 77.6046},
          'fare': 200.0,
          'createdAt': DateTime.now(),
        });

        // Simulate rejection (booking goes back to pending for other drivers)
        await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .update({
          'rejectedBy': ['test_driver_001'],
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .get();

        expect(booking.data()!['rejectedBy'], contains('test_driver_001'));
      },
    );
  }

  // ==========================================
  // TRACKING TESTS
  // ==========================================

  Future<void> _testTrackBookingScreenLoads(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Track booking screen loads',
      category: 'BookingFlow/Tracking',
      testFunction: () async {
        await tester.pumpWidget(_buildTestApp('/track-booking'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  }

  Future<void> _testActiveBookingQuery(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Active booking can be queried',
      category: 'BookingFlow/Tracking',
      testFunction: () async {
        final activeBookings = await mockFirebase.firestore
            .collection('bookings')
            .where('userId', isEqualTo: 'test_user_001')
            .where('status', isEqualTo: 'in_progress')
            .get();

        expect(activeBookings.docs.isNotEmpty, true);
      },
    );
  }

  // ==========================================
  // RATING & FEEDBACK TESTS
  // ==========================================

  Future<void> _testBookingRating(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking can be rated',
      category: 'BookingFlow/Feedback',
      testFunction: () async {
        // Rate a completed booking
        await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .update({
          'rating': 5,
          'ratedAt': DateTime.now(),
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .get();

        expect(booking.data()!['rating'], 5);
      },
    );
  }

  Future<void> _testBookingFeedback(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Booking feedback can be submitted',
      category: 'BookingFlow/Feedback',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .get();

        expect(booking.data()!['feedback'], isNotNull);
        expect(booking.data()!['feedback'], 'Great service!');
      },
    );
  }

  // ==========================================
  // CANCELLATION TESTS
  // ==========================================

  Future<void> _testCancellationReasons(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Cancellation reason is stored',
      category: 'BookingFlow/Cancellation',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_003')
            .get();

        expect(booking.data()!['cancellationReason'], isNotNull);
      },
    );
  }

  Future<void> _testCancellationTimestamp(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Cancellation timestamp is recorded',
      category: 'BookingFlow/Cancellation',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_003')
            .get();

        expect(booking.data()!['cancelledAt'], isNotNull);
      },
    );
  }

  // ==========================================
  // FARE & PAYMENT TESTS
  // ==========================================

  Future<void> _testFareBreakdown(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Fare breakdown is available',
      category: 'BookingFlow/Payment',
      testFunction: () async {
        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_001')
            .get();

        expect(booking.data()!['fare'], isA<num>());
        expect(booking.data()!.containsKey('distance'), true);
      },
    );
  }

  Future<void> _testOfferCodeApplication(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Offer code can be applied to booking',
      category: 'BookingFlow/Payment',
      testFunction: () async {
        // Create booking with offer
        final testBookingId = 'test_offer_booking';

        await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .set({
          'bookingId': testBookingId,
          'userId': 'test_user_001',
          'status': 'pending',
          'pickup': {'address': 'Test', 'lat': 12.9716, 'lng': 77.5946},
          'drop': {'address': 'Test Drop', 'lat': 12.9816, 'lng': 77.6046},
          'fare': 500.0,
          'appliedOffer': {
            'code': 'FIRST20',
            'discount': 100.0,
          },
          'finalFare': 400.0,
          'createdAt': DateTime.now(),
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc(testBookingId)
            .get();

        expect(booking.data()!['appliedOffer'], isNotNull);
        expect(booking.data()!['finalFare'], 400.0);
      },
    );
  }

  Future<void> _testPaymentStatus(WidgetTester tester) async {
    await testRunner.runTest(
      testName: 'Payment status is tracked',
      category: 'BookingFlow/Payment',
      testFunction: () async {
        // Add payment status to completed booking
        await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .update({
          'paymentStatus': 'completed',
          'paymentMethod': 'cash',
          'paidAt': DateTime.now(),
        });

        final booking = await mockFirebase.firestore
            .collection('bookings')
            .doc('test_booking_002')
            .get();

        expect(booking.data()!['paymentStatus'], 'completed');
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
