const {
  tearDown,
  seed,
  asUser,
  assertSucceeds,
  assertFails,
} = require("./helpers");

const UID = "rider-001";

async function seedRider(overrides = {}) {
  await seed(`users/${UID}`, {
    email: "r@example.com",
    mobile: "9000000000",
    authMethod: "email",
    role: "User",
    verificationStatus: "pending",
    rating: 4.5,
    totalRides: 12,
    ...overrides,
  });
}

describe("users/{uid} update — field whitelist (PR 3 / V-06)", () => {
  after(tearDown);
  beforeEach(async () => {
    const {getEnv} = require("./helpers");
    const env = await getEnv();
    await env.clearFirestore();
  });

  it("allows the owner to update whitelisted profile fields", async () => {
    await seedRider();
    const db = await asUser(UID);
    await assertSucceeds(
        db.doc(`users/${UID}`).update({fullName: "New Name"}),
    );
  });

  it("allows owner to update fcmToken (NotificationService path)", async () => {
    await seedRider();
    const db = await asUser(UID);
    await assertSucceeds(
        db.doc(`users/${UID}`).update({fcmToken: "tkn-123"}),
    );
  });

  it("denies setting isAdmin to true", async () => {
    await seedRider();
    const db = await asUser(UID);
    await assertFails(
        db.doc(`users/${UID}`).update({isAdmin: true}),
    );
  });

  it("denies overwriting admin-only verificationApprovedAt", async () => {
    await seedRider();
    const db = await asUser(UID);
    await assertFails(
        db.doc(`users/${UID}`).update({verificationApprovedAt: new Date()}),
    );
  });

  it("denies overwriting rating", async () => {
    await seedRider();
    const db = await asUser(UID);
    await assertFails(
        db.doc(`users/${UID}`).update({rating: 5.0}),
    );
  });

  it("denies overwriting totalRides", async () => {
    await seedRider();
    const db = await asUser(UID);
    await assertFails(
        db.doc(`users/${UID}`).update({totalRides: 999}),
    );
  });

  it("allows pending → submitted verificationStatus transition", async () => {
    await seedRider({verificationStatus: "pending"});
    const db = await asUser(UID);
    await assertSucceeds(
        db.doc(`users/${UID}`).update({verificationStatus: "submitted"}),
    );
  });

  it("denies user self-approval (submitted → approved)", async () => {
    await seedRider({verificationStatus: "submitted"});
    const db = await asUser(UID);
    await assertFails(
        db.doc(`users/${UID}`).update({verificationStatus: "approved"}),
    );
  });

  it("denies updates by a different authenticated user", async () => {
    await seedRider();
    const db = await asUser("intruder-002");
    await assertFails(
        db.doc(`users/${UID}`).update({fullName: "hacked"}),
    );
  });
});
