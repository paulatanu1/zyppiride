const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure Nodemailer (e.g., Gmail with App Password)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "atanupaul76@gmail.com", // Replace with your email
    pass: "vstv abwo zsch yoxb",
  },
});

exports.sendEmailOTP = functions.https.onCall(async (data, context) => {
  const {email, userId} = data;
  if (!email || !userId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing email or userId",
    );
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5-minute expiry

  // Store OTP in Firestore
  await admin
      .firestore()
      .collection("otps")
      .doc(userId)
      .set({
        otp,
        email,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

  // Send OTP email
  await transporter.sendMail({
    from: "atanupaul76@gmail.com",
    to: email,
    subject: "Zyppi Ride OTP Verification",
    html: `
  <p>Your OTP for Zyppi Ride registration is: <strong>${otp}</strong>.</p>
  <p>It expires in 5 minutes.</p>
`,
  });

  return {success: true, message: "OTP sent successfully"};
});
