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
