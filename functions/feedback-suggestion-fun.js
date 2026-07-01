const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.createComplaint = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to create a complaint",
    );
  }
  const userId = context.auth.uid;

  const subject = data.subject || "General";
  const description = data.description || "";
  const priority = data.priority || "Medium";
  const imageUrl = data.imageUrl || null;

  // Generate ticket ID
  const now = new Date();
  const dateStr = now.toISOString().split("T")[0].replace(/-/g, "");
  const seq = Math.floor(Math.random() * 900) + 100;
  const ticketId = `ZY-${dateStr}-${String(seq)}`;

  // Save to Firestore
  const complaintRef = db.collection("complaints").doc();
  await complaintRef.set({
    ticketId,
    userId,
    subject,
    description,
    priority,
    imageUrl,
    status: "Pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {ticketId, success: true};
});

exports.createFeedback = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to submit feedback",
    );
  }
  const userId = context.auth.uid;

  const rating = data.rating || 0;
  const message = data.message || "";
  const imageUrl = data.imageUrl || null;

  // Generate feedback ID
  const now = new Date();
  const dateStr = now.toISOString().split("T")[0].replace(/-/g, "");
  const seq = Math.floor(Math.random() * 900) + 100;
  const feedbackId = `FB-${dateStr}-${String(seq)}`;

  // Save to Firestore
  const feedbackRef = db.collection("feedbacks").doc();
  await feedbackRef.set({
    feedbackId,
    userId,
    rating,
    message,
    imageUrl,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {feedbackId, success: true};
});
