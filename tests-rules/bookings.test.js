const {
  getEnv,
  tearDown,
  seed,
  asUser,
  assertSucceeds,
  assertFails,
} = require("./helpers");

const RIDER = "rider-101";
const DRIVER = "driver-202";
const VEHICLE = "veh-303";
const BOOKING = "book-404";

async function seedBooking(status = "arrived", overrides = {}) {
  await seed(`vehicles/${VEHICLE}`, {
    userId: DRIVER,
    documentStatus: "approved",
  });
  await seed(`bookings/${BOOKING}`, {
    userId: RIDER,
    userPhone: "9000000000",
    userName: "Rider",
    bookingType: "local",
    status,
    pickupLocation: {lat: 0, lng: 0},
    dropLocation: {lat: 1, lng: 1},
    vehicle: {vehicleId: VEHICLE, type: "sedan"},
    vehicleId: VEHICLE,
    driver: {driverId: DRIVER},
    fareDetails: {totalFare: 100},
    paymentMethod: "cash",
    paymentStatus: "pending",
    createdAt: new Date(),
    updatedAt: new Date(),
    rideOtp: "123456",
    ...overrides,
  });
}

describe("bookings/{id} — driver cannot write status=inProgress (PR 5 / V-04)", () => {
  after(tearDown);
  beforeEach(async () => {
    const env = await getEnv();
    await env.clearFirestore();
  });

  it("denies driver writing status=inProgress directly", async () => {
    await seedBooking("arrived");
    const db = await asUser(DRIVER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "inProgress",
          updatedAt: new Date(),
        }),
    );
  });

  it("allows driver to flip status=arrived (still permitted)", async () => {
    await seedBooking("driverArriving");
    const db = await asUser(DRIVER);
    await assertSucceeds(
        db.doc(`bookings/${BOOKING}`).update({
          status: "arrived",
          updatedAt: new Date(),
        }),
    );
  });

  it("allows driver to flip status=confirmed on accept", async () => {
    await seedBooking("pending");
    const db = await asUser(DRIVER);
    await assertSucceeds(
        db.doc(`bookings/${BOOKING}`).update({
          status: "confirmed",
          confirmedAt: new Date(),
          updatedAt: new Date(),
        }),
    );
  });

  it("allows driver to cancel", async () => {
    await seedBooking("confirmed");
    const db = await asUser(DRIVER);
    await assertSucceeds(
        db.doc(`bookings/${BOOKING}`).update({
          status: "cancelled",
          cancelledAt: new Date(),
          cancelledBy: DRIVER,
          updatedAt: new Date(),
        }),
    );
  });

  it("denies rider writing status=inProgress", async () => {
    await seedBooking("arrived");
    const db = await asUser(RIDER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "inProgress",
          updatedAt: new Date(),
        }),
    );
  });

  it("allows rider to cancel a pending booking", async () => {
    await seedBooking("pending");
    const db = await asUser(RIDER);
    await assertSucceeds(
        db.doc(`bookings/${BOOKING}`).update({
          status: "cancelled",
          cancelledAt: new Date(),
          cancelledBy: RIDER,
          updatedAt: new Date(),
        }),
    );
  });

  it("denies rider writing status=completed (only cancelled allowed)", async () => {
    await seedBooking("confirmed");
    const db = await asUser(RIDER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "completed",
          updatedAt: new Date(),
        }),
    );
  });

  it("denies rider writing status=confirmed", async () => {
    await seedBooking("pending");
    const db = await asUser(RIDER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "confirmed",
          updatedAt: new Date(),
        }),
    );
  });

  it("denies a different driver from updating someone else's booking", async () => {
    await seedBooking("arrived");
    const db = await asUser("other-driver-999");
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "arrived",
          updatedAt: new Date(),
        }),
    );
  });
});

describe("bookings/{id} — driver state machine (W5)", () => {
  after(tearDown);
  beforeEach(async () => {
    const env = await getEnv();
    await env.clearFirestore();
  });

  it("allows completing from inProgress with end-of-trip fare recalculation", async () => {
    await seedBooking("inProgress");
    const db = await asUser(DRIVER);
    await assertSucceeds(
        db.doc(`bookings/${BOOKING}`).update({
          status: "completed",
          completedAt: new Date(),
          fareDetails: {totalFare: 180},
          estimatedDistance: 12.4,
          estimatedDuration: 38,
          updatedAt: new Date(),
        }),
    );
  });

  it("denies jumping straight to completed from confirmed", async () => {
    await seedBooking("confirmed");
    const db = await asUser(DRIVER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "completed",
          completedAt: new Date(),
          updatedAt: new Date(),
        }),
    );
  });

  it("denies editing fareDetails mid-ride (status transition without completion)", async () => {
    await seedBooking("confirmed");
    const db = await asUser(DRIVER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "driverArriving",
          fareDetails: {totalFare: 999},
          updatedAt: new Date(),
        }),
    );
  });

  it("denies editing fareDetails without any status change", async () => {
    await seedBooking("arrived");
    const db = await asUser(DRIVER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          fareDetails: {totalFare: 999},
          updatedAt: new Date(),
        }),
    );
  });

  it("allows the driver to rate the rider after completion", async () => {
    await seedBooking("completed");
    const db = await asUser(DRIVER);
    await assertSucceeds(
        db.doc(`bookings/${BOOKING}`).update({
          driverRating: 5,
          driverReview: "Great rider",
          updatedAt: new Date(),
        }),
    );
  });

  it("denies rating bundled with any other field", async () => {
    await seedBooking("completed");
    const db = await asUser(DRIVER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          driverRating: 5,
          fareDetails: {totalFare: 999},
          updatedAt: new Date(),
        }),
    );
  });

  it("denies reverting a completed booking to an earlier status", async () => {
    await seedBooking("completed");
    const db = await asUser(DRIVER);
    await assertFails(
        db.doc(`bookings/${BOOKING}`).update({
          status: "inProgress",
          updatedAt: new Date(),
        }),
    );
  });
});

describe("bookings/{id}/private — rider-only OTP subcollection (W1)", () => {
  after(tearDown);
  beforeEach(async () => {
    const env = await getEnv();
    await env.clearFirestore();
    await seedBooking("arrived");
    await seed(`bookings/${BOOKING}/private/otp`, {
      rideOtp: "654321",
      otpFailedAttempts: 0,
      otpLockedUntil: null,
    });
  });

  it("allows the rider to read their ride OTP", async () => {
    const db = await asUser(RIDER);
    await assertSucceeds(db.doc(`bookings/${BOOKING}/private/otp`).get());
  });

  it("denies the assigned driver from reading the OTP", async () => {
    const db = await asUser(DRIVER);
    await assertFails(db.doc(`bookings/${BOOKING}/private/otp`).get());
  });

  it("denies any client write to the OTP doc", async () => {
    const db = await asUser(RIDER);
    await assertFails(
        db.doc(`bookings/${BOOKING}/private/otp`).update({rideOtp: "000000"}),
    );
  });
});
