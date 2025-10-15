const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");

admin.initializeApp();
const db = admin.firestore();

// Set via:
// firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY" admin.emails="admin@zyppi.in,developerzyppi@gmail.com"

exports.createComplaint = functions.https.onCall(async (data, context) => {
  const userId = data.userId || "unknown";
  const subject = data.subject || "General";
  const description = data.description || "";
  const priority = data.priority || "Medium";
  const imageUrl = data.imageUrl || null;

  const counterRef = db.collection("support_meta").doc("counters");
  let ticketId;

  await db.runTransaction(async (t) => {
    const snap = await t.get(counterRef);
    let seq = 1;
    if (!snap.exists) {
      t.set(counterRef, {complaintSeq: 1}, {merge: true});
      seq = 1;
    } else {
      const current = snap.get("complaintSeq") || 0;
      seq = current + 1;
      t.update(counterRef, {complaintSeq: seq});
    }

    const now = new Date();
    const dateStr = now.toISOString().split("T")[0].replace(/-/g, "");
    ticketId = `ZY-${dateStr}-${String(seq).padStart(3, "0")}`;

    const complaintRef = db.collection("complaints").doc();
    t.set(complaintRef, {
      ticketId,
      userId,
      subject,
      description,
      priority,
      imageUrl,
      status: "Pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  try {
    const config = functions.config();
    const sendgridKey = config.sendgrid && config.sendgrid.key;
    const adminEmails =
      config.admin && config.admin.emails ?
        config.admin.emails.split(",") :
        ["admin@zyppi.in"];

    if (sendgridKey) {
      sgMail.setApiKey(sendgridKey);
      const msg = {
        to: adminEmails,
        from: "no-reply@zyppi.in",
        subject: `New Support Ticket: ${ticketId} — ${subject}`,
        text:
          `Ticket: ${ticketId}\nUser: ${userId}\nPriority: ${priority}\n\n${description}` +
          (imageUrl ? `\n\nImage: ${imageUrl}` : ""),
      };
      await sgMail.send(msg);
    }
  } catch (err) {
    console.error("Error sending mail", err);
  }

  return {ticketId};
});

exports.createFeedback = functions.https.onCall(async (data, context) => {
  const userId = data.userId || "unknown";
  const rating = data.rating || 0;
  const message = data.message || "";
  const imageUrl = data.imageUrl || null;

  const feedbackRef = db.collection("feedbacks").doc();
  await feedbackRef.set({
    userId,
    rating,
    message,
    imageUrl,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const config = functions.config();
    const sendgridKey = config.sendgrid && config.sendgrid.key;
    const adminEmails =
      config.admin && config.admin.emails ?
        config.admin.emails.split(",") :
        ["admin@zyppi.in"];

    if (sendgridKey) {
      sgMail.setApiKey(sendgridKey);
      const msg = {
        to: adminEmails,
        from: "no-reply@zyppi.in",
        subject: `New Feedback from ${userId} — Rating: ${rating}`,
        text: `${message}` + (imageUrl ? `\n\nImage: ${imageUrl}` : ""),
      };
      await sgMail.send(msg);
    }
  } catch (err) {
    console.error("Error sending feedback mail", err);
  }

  return {feedbackId: feedbackRef.id};
});
