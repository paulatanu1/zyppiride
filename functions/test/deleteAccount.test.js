/**
 * Tests the deleteAccount callable (Play User Data policy).
 *
 * Runs against the Firestore + Auth emulators (started by `npm test` via
 * firebase emulators:exec --only firestore,auth).
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

const UID = "delete-me-1";
const OTHER = "other-user-1";
const VEHICLE = "veh-del-1";

async function seedAccount() {
  const db = admin.firestore();
  await admin.auth().createUser({uid: UID});
  await db.doc(`users/${UID}`).set({email: "x@y.z", mobile: "9999999999"});
  await db.doc(`users/${UID}/savedAddresses/home`).set({label: "Home"});
  await db.doc(`vehicles/${VEHICLE}`).set({userId: UID, documentStatus: "approved"});
  await db.doc(`vehicles/${VEHICLE}/documents/rc`).set({url: "gs://x"});
  await db.doc(`agreements/${UID}_${VEHICLE}`).set({userId: UID, signatureData: "base64..."});
  await db.doc(`drivers/${UID}`).set({latitude: 1, longitude: 2});
  await db.doc(`bookings/b-rider`).set({
    userId: UID, userName: "Real Name", userPhone: "9999999999",
    driver: {driverId: OTHER}, status: "completed",
    fareDetails: {totalFare: 250},
  });
  await db.doc(`bookings/b-driver`).set({
    userId: OTHER, userName: "Someone Else",
    driver: {driverId: UID, name: "Real Driver", phone: "8888888888"},
    status: "completed", fareDetails: {totalFare: 100},
  });
}

async function callAs(uid) {
  const wrapped = tester.wrap(functions.deleteAccount);
  return wrapped({data: {}, auth: {uid}});
}

describe("deleteAccount", () => {
  before(() => {
    if (admin.apps.length === 0) admin.initializeApp();
  });
  after(() => tester.cleanup());
  beforeEach(async () => {
    const db = admin.firestore();
    for (const coll of ["users", "vehicles", "agreements", "drivers", "bookings"]) {
      await db.recursiveDelete(db.collection(coll));
    }
    try {
      await admin.auth().deleteUser(UID);
    } catch (e) {/* not created yet */}
  });

  it("rejects unauthenticated callers", async () => {
    const wrapped = tester.wrap(functions.deleteAccount);
    await assert.rejects(() => wrapped({data: {}}), (err) => {
      assert.strictEqual(err.code, "unauthenticated");
      return true;
    });
  });

  it("deletes user doc, subcollections, vehicles, agreements, drivers doc and auth user", async () => {
    await seedAccount();
    const res = await callAs(UID);
    assert.strictEqual(res.success, true);

    const db = admin.firestore();
    assert.strictEqual((await db.doc(`users/${UID}`).get()).exists, false);
    assert.strictEqual(
        (await db.doc(`users/${UID}/savedAddresses/home`).get()).exists, false);
    assert.strictEqual((await db.doc(`vehicles/${VEHICLE}`).get()).exists, false);
    assert.strictEqual(
        (await db.doc(`vehicles/${VEHICLE}/documents/rc`).get()).exists, false);
    assert.strictEqual(
        (await db.doc(`agreements/${UID}_${VEHICLE}`).get()).exists, false);
    assert.strictEqual((await db.doc(`drivers/${UID}`).get()).exists, false);

    await assert.rejects(() => admin.auth().getUser(UID), (err) => {
      assert.strictEqual(err.code, "auth/user-not-found");
      return true;
    });
  });

  it("anonymizes bookings instead of deleting them", async () => {
    await seedAccount();
    await callAs(UID);

    const db = admin.firestore();
    const rider = (await db.doc(`bookings/b-rider`).get()).data();
    assert.strictEqual(rider.userName, "Deleted user");
    assert.strictEqual(rider.userPhone, undefined);
    assert.strictEqual(rider.accountDeleted, true);
    assert.strictEqual(rider.fareDetails.totalFare, 250);

    const asDriver = (await db.doc(`bookings/b-driver`).get()).data();
    assert.strictEqual(asDriver.driver.name, "Deleted driver");
    assert.strictEqual(asDriver.driver.phone, undefined);
    assert.strictEqual(asDriver.driver.driverId, UID);
    assert.strictEqual(asDriver.userName, "Someone Else");
  });

  it("does not touch other users' data", async () => {
    await seedAccount();
    const db = admin.firestore();
    await db.doc(`users/${OTHER}`).set({email: "keep@me.com"});
    await db.doc(`vehicles/veh-keep`).set({userId: OTHER});

    await callAs(UID);

    assert.strictEqual((await db.doc(`users/${OTHER}`).get()).exists, true);
    assert.strictEqual((await db.doc(`vehicles/veh-keep`).get()).exists, true);
  });

  it("succeeds even when the auth account is already gone", async () => {
    const db = admin.firestore();
    await db.doc(`users/${UID}`).set({email: "x@y.z"});
    // No admin.auth().createUser — simulates a half-deleted account.
    const res = await callAs(UID);
    assert.strictEqual(res.success, true);
    assert.strictEqual((await db.doc(`users/${UID}`).get()).exists, false);
  });
});
