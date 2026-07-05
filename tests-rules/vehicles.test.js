const {
  getEnv,
  tearDown,
  seed,
  asUser,
  assertSucceeds,
  assertFails,
} = require("./helpers");

const OWNER = "owner-111";
const VEHICLE = "veh-222";

async function seedVehicle(overrides = {}) {
  await seed(`vehicles/${VEHICLE}`, {
    userId: OWNER,
    documentStatus: "pending",
    isOnline: false,
    createdAt: new Date(),
    ...overrides,
  });
}

describe("vehicles/{id} — documentStatus is admin-gated", () => {
  after(tearDown);
  beforeEach(async () => {
    const env = await getEnv();
    await env.clearFirestore();
  });

  it("allows owner to create a vehicle with documentStatus=pending", async () => {
    const db = await asUser(OWNER);
    await assertSucceeds(
        db.doc(`vehicles/${VEHICLE}`).set({
          userId: OWNER,
          documentStatus: "pending",
          createdAt: new Date(),
        }),
    );
  });

  it("denies creating a vehicle pre-approved", async () => {
    const db = await asUser(OWNER);
    await assertFails(
        db.doc(`vehicles/${VEHICLE}`).set({
          userId: OWNER,
          documentStatus: "approved",
          createdAt: new Date(),
        }),
    );
  });

  it("denies owner self-approving documentStatus", async () => {
    await seedVehicle();
    const db = await asUser(OWNER);
    await assertFails(
        db.doc(`vehicles/${VEHICLE}`).update({documentStatus: "approved"}),
    );
  });

  it("allows owner to submit documents (documentStatus=submitted)", async () => {
    await seedVehicle();
    const db = await asUser(OWNER);
    await assertSucceeds(
        db.doc(`vehicles/${VEHICLE}`).update({
          documentStatus: "submitted",
          submittedAt: new Date(),
        }),
    );
  });

  it("denies owner reassigning the vehicle to another uid", async () => {
    await seedVehicle();
    const db = await asUser(OWNER);
    await assertFails(
        db.doc(`vehicles/${VEHICLE}`).update({userId: "someone-else"}),
    );
  });

  it("denies going online while documentStatus is pending", async () => {
    await seedVehicle({documentStatus: "pending"});
    const db = await asUser(OWNER);
    await assertFails(
        db.doc(`vehicles/${VEHICLE}`).update({isOnline: true}),
    );
  });

  it("allows going online once admin approved the documents", async () => {
    await seedVehicle({documentStatus: "approved"});
    const db = await asUser(OWNER);
    await assertSucceeds(
        db.doc(`vehicles/${VEHICLE}`).update({
          isOnline: true,
          lastOnlineAt: new Date(),
        }),
    );
  });
});
