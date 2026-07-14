/**
 * Tests OTP generation in onBookingCreated (W1): the OTP must land in the
 * rules-protected private/ subcollection, never on the driver-readable
 * booking document.
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

const BOOKING = "book-otpgen-1";

async function invokeWith(bookingData) {
  await admin.firestore().doc(`bookings/${BOOKING}`).set(bookingData);
  // Use a real emulator snapshot so snap.ref writes land in the same
  // Firestore the assertions read (makeDocumentSnapshot binds its ref to
  // a separate app instance).
  const snap = await admin.firestore().doc(`bookings/${BOOKING}`).get();
  const wrapped = tester.wrap(functions.onBookingCreated);
  await wrapped({data: snap, params: {bookingId: BOOKING}});
}

describe("onBookingCreated — server-side OTP generation", () => {
  before(() => {
    if (admin.apps.length === 0) admin.initializeApp();
  });
  after(() => tester.cleanup());
  beforeEach(async () => {
    const db = admin.firestore();
    await db.recursiveDelete(db.collection("bookings"));
  });

  it("writes a 6-digit OTP to the private subcollection only", async () => {
    await invokeWith({
      userId: "rider-otpgen",
      driver: {driverId: "driver-otpgen"},
      status: "pending",
      vehicle: {type: "sedan"},
    });

    const otpSnap = await admin.firestore()
        .doc(`bookings/${BOOKING}/private/otp`).get();
    assert.strictEqual(otpSnap.exists, true);
    assert.match(otpSnap.data().rideOtp, /^\d{6}$/);
    assert.strictEqual(otpSnap.data().otpFailedAttempts, 0);

    const bookingSnap =
        await admin.firestore().doc(`bookings/${BOOKING}`).get();
    assert.strictEqual(bookingSnap.data().rideOtp, undefined);
  });

  it("scrubs a client-written rideOtp from the booking document", async () => {
    await invokeWith({
      userId: "rider-otpgen",
      driver: {driverId: "driver-otpgen"},
      status: "pending",
      vehicle: {type: "sedan"},
      rideOtp: "111111", // hostile/legacy client wrote its own OTP
    });

    const bookingSnap =
        await admin.firestore().doc(`bookings/${BOOKING}`).get();
    assert.strictEqual(bookingSnap.data().rideOtp, undefined);

    // The server-generated OTP is independent of the client's value.
    const otpSnap = await admin.firestore()
        .doc(`bookings/${BOOKING}/private/otp`).get();
    assert.match(otpSnap.data().rideOtp, /^\d{6}$/);
  });
});
