const {
  getEnv,
  tearDown,
  seed,
  asUser,
  assertSucceeds,
  assertFails,
} = require("./helpers");

const USER = "support-user-1";

describe("complaints/feedbacks — server-only creation (W4)", () => {
  after(tearDown);
  beforeEach(async () => {
    const env = await getEnv();
    await env.clearFirestore();
  });

  it("denies direct client complaint creation", async () => {
    const db = await asUser(USER);
    await assertFails(
        db.collection("complaints").add({
          userId: USER,
          ticketId: "ZY-20260715-0001",
          subject: "s",
          description: "d",
          priority: "High",
          status: "Pending",
          createdAt: new Date(),
        }),
    );
  });

  it("denies direct client feedback creation", async () => {
    const db = await asUser(USER);
    await assertFails(
        db.collection("feedbacks").add({
          userId: USER,
          feedbackId: "FB-20260715-0001",
          rating: 5,
          message: "m",
          createdAt: new Date(),
        }),
    );
  });

  it("still allows the owner to read their complaint", async () => {
    await seed("complaints/c1", {
      userId: USER,
      ticketId: "ZY-20260715-0001",
      status: "Pending",
    });
    const db = await asUser(USER);
    await assertSucceeds(db.doc("complaints/c1").get());
  });

  it("denies other users from reading someone's complaint", async () => {
    await seed("complaints/c1", {userId: USER, ticketId: "ZY-1"});
    const db = await asUser("someone-else");
    await assertFails(db.doc("complaints/c1").get());
  });

  it("denies clients from touching the ticket counter", async () => {
    const db = await asUser(USER);
    await assertFails(
        db.doc("counters/supportTickets").set({complaint: 9999}),
    );
    await assertFails(db.doc("counters/supportTickets").get());
  });
});
