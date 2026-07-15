import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyppi_ride/models/booking_model.dart';
import 'package:zyppi_ride/services/booking_service.dart';

/// Money-path tests for manual cash payment recording, run against an
/// in-memory Firestore (fake_cloud_firestore).
void main() {
  const bookingId = 'pay-test-1';
  const driverId = 'driver-1';

  Booking makeBooking({
    BookingStatus status = BookingStatus.completed,
    double totalFare = 200,
    double? amountReceived,
  }) {
    final now = DateTime.now();
    return Booking(
      bookingId: bookingId,
      userId: 'rider-1',
      userPhone: '9000000000',
      userName: 'Rider',
      bookingType: BookingType.local,
      status: status,
      pickupLocation: const BookingLocation(
        address: 'A',
        latitude: 0,
        longitude: 0,
      ),
      dropLocation: const BookingLocation(
        address: 'B',
        latitude: 1,
        longitude: 1,
      ),
      vehicle: const BookingVehicleDetails(
        vehicleId: 'veh-1',
        type: 'sedan',
        brand: 'Maruti Suzuki',
        model: 'Dzire',
        registrationNumber: 'WB00AA0000',
        color: 'White',
        seatingCapacity: 4,
        hasAC: true,
      ),
      driver: const BookingDriverDetails(
        driverId: driverId,
        name: 'Driver',
        rating: 4.5,
        totalTrips: 100,
      ),
      fareDetails: FareDetails.calculate(
        baseFare: totalFare,
        perKmRate: 0,
        distanceKm: 0,
        gstPercent: 0,
      ),
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.pending,
      createdAt: now,
      updatedAt: now,
      amountReceived: amountReceived,
    );
  }

  late FakeFirebaseFirestore firestore;
  late BookingService service;

  Future<void> seed(Booking booking) async {
    await firestore.collection('bookings').doc(bookingId).set(booking.toMap());
  }

  Future<Map<String, dynamic>> stored() async =>
      (await firestore.collection('bookings').doc(bookingId).get()).data()!;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = BookingService(firestore: firestore);
  });

  group('recordPaymentReceived', () {
    test('full payment marks the booking paid with zero remaining', () async {
      await seed(makeBooking(totalFare: 200));
      final result = await service.recordPaymentReceived(
        bookingId: bookingId,
        driverId: driverId,
        amountReceived: 200,
      );
      expect(result.isSuccess, isTrue);

      final data = await stored();
      expect(data['amountReceived'], 200);
      expect(data['remainingAmount'], 0);
      expect(data['paymentStatus'], 'completed');
      expect(data['paymentRecordedManually'], true);
      expect(data['paymentReceivedBy'], driverId);
    });

    test('partial payment stays pending with the correct remainder', () async {
      await seed(makeBooking(totalFare: 200));
      await service.recordPaymentReceived(
        bookingId: bookingId,
        driverId: driverId,
        amountReceived: 120,
      );

      final data = await stored();
      expect(data['amountReceived'], 120);
      expect(data['remainingAmount'], 80);
      expect(data['paymentStatus'], 'pending');
    });

    test('second installment accumulates and settles the fare', () async {
      await seed(makeBooking(totalFare: 200, amountReceived: 120));
      await service.recordPaymentReceived(
        bookingId: bookingId,
        driverId: driverId,
        amountReceived: 80,
      );

      final data = await stored();
      expect(data['amountReceived'], 200);
      expect(data['remainingAmount'], 0);
      expect(data['paymentStatus'], 'completed');
    });

    test('overpayment clamps remaining at zero, never negative', () async {
      await seed(makeBooking(totalFare: 200));
      await service.recordPaymentReceived(
        bookingId: bookingId,
        driverId: driverId,
        amountReceived: 500,
      );

      final data = await stored();
      expect(data['remainingAmount'], 0);
      expect(data['paymentStatus'], 'completed');
    });

    test('rejects a driver who is not assigned to the booking', () async {
      await seed(makeBooking());
      final result = await service.recordPaymentReceived(
        bookingId: bookingId,
        driverId: 'impostor',
        amountReceived: 200,
      );
      expect(result.isFailure, isTrue);
      expect((await stored())['paymentRecordedManually'], isNot(true));
    });

    test('rejects recording on a trip that is not completed', () async {
      await seed(makeBooking(status: BookingStatus.inProgress));
      final result = await service.recordPaymentReceived(
        bookingId: bookingId,
        driverId: driverId,
        amountReceived: 200,
      );
      expect(result.isFailure, isTrue);
    });

    test('rejects an unknown booking id', () async {
      final result = await service.recordPaymentReceived(
        bookingId: 'does-not-exist',
        driverId: driverId,
        amountReceived: 200,
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('Booking serialization', () {
    test('toMap → fromFirestore round-trip preserves the money fields',
        () async {
      await seed(makeBooking(totalFare: 350, amountReceived: 100));
      final restored = await service.getBooking(bookingId);

      expect(restored, isNotNull);
      expect(restored!.fareDetails.totalFare, closeTo(350, 0.001));
      expect(restored.amountReceived, 100);
      expect(restored.status, BookingStatus.completed);
      expect(restored.driver.driverId, driverId);
      expect(restored.paymentMethod, PaymentMethod.cash);
    });
  });
}
