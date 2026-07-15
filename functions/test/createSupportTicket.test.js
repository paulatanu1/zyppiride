/**
 * Tests the createSupportTicket callable (W4): sequential, collision-free
 * ticket IDs from a transactional counter, plus server-side validation.
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

const UID = "support-user-1";

async function callAs(data, uid = UID) {
  const wrapped = tester.wrap(functions.createSupportTicket);
  return wrapped({data, auth: {uid}});
}

function rejectsWithCode(fn, code) {
  return assert.rejects(fn, (err) => {
    assert.strictEqual(err.code, code);
    return true;
  });
}

const COMPLAINT = {
  kind: "complaint",
  subject: "App not responding",
  description: "The booking screen froze.",
  priority: "High",
};

describe("createSupportTicket", () => {
  before(() => {
    if (admin.apps.length === 0) admin.initializeApp();
  });
  after(() => tester.cleanup());
  beforeEach(async () => {
    const db = admin.firestore();
    for (const coll of ["complaints", "feedbacks", "counters"]) {
      await db.recursiveDelete(db.collection(coll));
    }
  });

  it("allocates sequential complaint ticket IDs", async () => {
    const first = await callAs(COMPLAINT);
    const second = await callAs(COMPLAINT);
    assert.match(first.ticketId, /^ZY-\d{8}-0001$/);
    assert.match(second.ticketId, /^ZY-\d{8}-0002$/);

    const docs = await admin.firestore().collection("complaints").get();
    assert.strictEqual(docs.size, 2);
    const stored = docs.docs.map((d) => d.data());
    assert.ok(stored.every((d) => d.userId === UID && d.status === "Pending"));
  });

  it("keeps feedback counter independent of complaints", async () => {
    await callAs(COMPLAINT);
    const fb = await callAs({kind: "feedback", rating: 4, message: "Nice app"});
    assert.match(fb.ticketId, /^FB-\d{8}-0001$/);

    const doc = (await admin.firestore().collection("feedbacks").get()).docs[0];
    assert.strictEqual(doc.data().rating, 4);
    assert.strictEqual(doc.data().feedbackId, fb.ticketId);
  });

  it("rejects invalid priority", async () => {
    await rejectsWithCode(
        () => callAs({...COMPLAINT, priority: "Urgent"}),
        "invalid-argument",
    );
  });

  it("rejects out-of-range rating", async () => {
    await rejectsWithCode(
        () => callAs({kind: "feedback", rating: 9, message: "x"}),
        "invalid-argument",
    );
  });

  it("rejects unknown kind", async () => {
    await rejectsWithCode(() => callAs({kind: "praise"}), "invalid-argument");
  });

  it("rejects unauthenticated callers", async () => {
    const wrapped = tester.wrap(functions.createSupportTicket);
    await rejectsWithCode(
        () => wrapped({data: COMPLAINT}),
        "unauthenticated",
    );
  });
});
