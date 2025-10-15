const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.createComplaint = functions.https.onCall(async (data, context) => {
  // Add logging
  console.log("=== createComplaint called ===");
  console.log("context.auth:", context.auth ? "EXISTS" : "NULL");
  console.log("context.auth.uid:", context.auth ? context.auth.uid : "N/A");
  console.log("data.userId:", data.userId);
  console.log("=============================");

  // Get userId from auth if available, otherwise from data
  let userId;
  if (context.auth) {
    userId = context.auth.uid;
    console.log("Using auth userId:", userId);
  } else if (data.userId) {
    userId = data.userId;
    console.log("Using data userId:", userId);
  } else {
    console.log("ERROR: No userId available!");
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated or provide userId to create a complaint",
    );
  }

  const subject = data.subject || "General";
  const description = data.description || "";
  const priority = data.priority || "Medium";
  const imageUrl = data.imageUrl || null;

  // Generate ticket ID
  const now = new Date();
  const dateStr = now.toISOString().split("T")[0].replace(/-/g, "");
  const seq = Math.floor(Math.random() * 900) + 100;
  const ticketId = `ZY-${dateStr}-${String(seq)}`;

  console.log("Generated ticketId:", ticketId);

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

  console.log("Complaint saved successfully");
  return {ticketId, success: true};
});

exports.createFeedback = functions.https.onCall(async (data, context) => {
  // Get userId from auth if available, otherwise from data
  let userId;
  if (context.auth) {
    userId = context.auth.uid;
  } else if (data.userId) {
    userId = data.userId;
  } else {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated or provide userId to submit feedback",
    );
  }

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
