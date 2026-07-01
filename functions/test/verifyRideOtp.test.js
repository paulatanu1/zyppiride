/**
 * Tests the verifyRideOtp callable (V-04).
 *
 * Runs against the Firestore emulator (auto-started by `npm test` via
 * firebase emulators:exec). The Functions SDK uses the admin SDK against
 * the emulator since FIRESTORE_EMULATOR_HOST is exported by emulators:exec.
 */
const assert = require("assert");
const ftest = require("firebase-functions-test");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "zyppiride-test";
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: process.env.GCLOUD_PROJECT,
});

const tester = ftest();
const admin = require("firebase-admin");
const functions = require("../index");

const DRIVER = "driver-u-1";
const RIDER = "rider-u-1";
const BOOKING = "book-otp-1";
const OTP = "654321";

async function seedBooking(overrides = {}) {
  await admin.firestore().doc(`bookings/${BOOKING}`).set({
    userId: RIDER,
    driver: {driverId: DRIVER},
    status: "arrived",
    rideOtp: OTP,
    ...overrides,
  });
}

async function callAsDriver(data, uid = DRIVER) {
  const wrapped = tester.wrap(functions.verifyRideOtp);
  return wrapped({data, auth: {uid}});
}

describe("verifyRideOtp", () => {
  before(() => {
    if (admin.apps.length === 0) admin.initializeApp();
  });
  after(() => tester.cleanup());
  beforeEach(async () => {
    await admin.firestore().recursiveDelete(
        admin.firestore().collection("bookings"),
    );
  });

  it("flips status to inProgress on correct OTP", async () => {
    await seedBooking();
    const res = await callAsDriver({bookingId: BOOKING, otp: OTP});
    assert.strictEqual(res.success, true);
    const snap = await admin.firestore().doc(`bookings/${BOOKING}`).get();
    assert.strictEqual(snap.data().status, "inProgress");
  });

  it("rejects when caller is not the assigned driver", async () => {
    await seedBooking();
    await assert.rejects(
        () => callAsDriver({bookingId: BOOKING, otp: OTP}, "other-driver"),
        /permission-denied/,
    );
  });

  it("rejects when booking status is not 'arrived'", async () => {
    await seedBooking({status: "confirmed"});
    await assert.rejects(
        () => callAsDriver({bookingId: BOOKING, otp: OTP}),
        /failed-precondition/,
    );
  });

  it("increments otpFailedAttempts on wrong OTP", async () => {
    await seedBooking();
    await assert.rejects(
        () => callAsDriver({bookingId: BOOKING, otp: "000000"}),
        /invalid-argument/,
    );
    const snap = await admin.firestore().doc(`bookings/${BOOKING}`).get();
    assert.strictEqual(snap.data().otpFailedAttempts, 1);
  });

  it("locks the booking after 3 wrong attempts", async () => {
    await seedBooking();
    for (let i = 0; i < 3; i++) {
      await assert.rejects(
          () => callAsDriver({bookingId: BOOKING, otp: "000000"}),
      );
    }
    const snap = await admin.firestore().doc(`bookings/${BOOKING}`).get();
    const data = snap.data();
    assert.strictEqual(data.otpFailedAttempts, 0);
    assert.ok(data.otpLockedUntil, "expected otpLockedUntil to be set");

    // Subsequent attempt — even with correct OTP — must be locked out.
    await assert.rejects(
        () => callAsDriver({bookingId: BOOKING, otp: OTP}),
        /resource-exhausted/,
    );
  });

  it("rejects unauthenticated callers", async () => {
    await seedBooking();
    const wrapped = tester.wrap(functions.verifyRideOtp);
    await assert.rejects(
        () => wrapped({data: {bookingId: BOOKING, otp: OTP}}),
        /unauthenticated/,
    );
  });

  it("rejects malformed payloads", async () => {
    await assert.rejects(
        () => callAsDriver({bookingId: BOOKING}),
        /invalid-argument/,
    );
  });

  it("rejects unknown booking", async () => {
    await assert.rejects(
        () => callAsDriver({bookingId: "does-not-exist", otp: OTP}),
        /not-found/,
    );
  });
});
