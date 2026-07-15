const crypto = require("crypto");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
admin.initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// OTP DELIVERY via Firebase Cloud Messaging (FCM)
//
// Fires whenever a new booking document is created.
// Reads the rideOtp from the booking and pushes it to the passenger's device
// via FCM — no third-party SMS provider required.
//
// The passenger sees it as a high-priority notification even when the app
// is in the background or closed. The OTP is also shown inside the app on
// the Track Booking screen as a fallback.
// ─────────────────────────────────────────────────────────────────────────────
exports.onBookingCreated = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const snap = event.data;
  const booking = snap.data();
  const {userId} = booking;
  const vehicleType = booking.vehicle?.type ?? "vehicle";
  const bookingId = event.params.bookingId;

  // Generate the OTP server-side and keep it OFF the booking document:
  // the assigned driver can read the booking, and a driver who can read
  // the OTP can self-verify pickup (W1). Riders read it from the
  // rules-protected private/ subcollection instead.
  const rideOtp = String(crypto.randomInt(100000, 1000000));
  await snap.ref.collection("private").doc("otp").set({
    rideOtp,
    otpFailedAttempts: 0,
    otpLockedUntil: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Defensive: scrub any client-written OTP from the booking document.
  if (booking.rideOtp) {
    await snap.ref.update({
      rideOtp: admin.firestore.FieldValue.delete(),
    });
  }

  try {
    await _sendOtpFcm(userId, rideOtp, vehicleType, bookingId);
    logger.info("OTP FCM notification sent for booking", bookingId);
  } catch (err) {
    logger.error("OTP FCM notification failed:", err);
  }

  return null;
});

/**
 * Pushes the ride OTP to the passenger's device via Firebase Cloud Messaging.
 *
 * The FCM token is stored on the user document under the key `fcmToken`
 * (written by NotificationService.saveFcmToken on the Flutter side).
 * If no token is found the function exits silently — the passenger can
 * still read the OTP from the Track Booking screen in the app.
 */
async function _sendOtpFcm(userId, otp, vehicleType, bookingId) {
  if (!userId) {
    logger.warn("No userId on booking — cannot send OTP notification");
    return;
  }

  const userSnap = await admin.firestore().collection("users").doc(userId).get();
  const fcmToken = userSnap.data()?.fcmToken;

  if (!fcmToken) {
    logger.info("No FCM token for user", userId, "— skipping OTP push");
    return;
  }

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: "Your Ride OTP",
      body: `OTP: ${otp} — Tell this to your ${vehicleType} driver when they arrive.`,
    },
    // Include otp in data so the app can handle/display it programmatically
    data: {
      type: "RIDE_OTP",
      bookingId: bookingId,
      otp: otp,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "zyppi_ride_channel",
        // Keep notification visible until the user dismisses it
        sticky: false,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RIDE OTP VERIFICATION
//
// Drivers verify the rider's pickup OTP through this callable rather than
// writing the booking status directly. Comparing OTPs server-side lets us
// enforce per-booking attempt counters and lockouts that a modified driver
// client cannot bypass (V-04).
// ─────────────────────────────────────────────────────────────────────────────
const OTP_MAX_ATTEMPTS = 3;
const OTP_LOCKOUT_MS = 5 * 60 * 1000;

exports.verifyRideOtp = onCall({enforceAppCheck: true}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const driverUid = request.auth.uid;
  const {bookingId, otp} = request.data || {};
  if (typeof bookingId !== "string" || typeof otp !== "string") {
    throw new HttpsError("invalid-argument", "bookingId and otp required.");
  }

  const db = admin.firestore();
  const ref = db.collection("bookings").doc(bookingId);

  // The transaction returns a discriminated result rather than throwing.
  // Throwing inside runTransaction aborts the tx and rolls back tx.update(),
  // which would silently discard the failed-attempts counter and lockout.
  // We commit the write via the transaction, then translate the result to
  // an HttpsError outside.
  // The OTP and its attempt counters live in the rules-protected
  // private/ subcollection (written by onBookingCreated), never on the
  // driver-readable booking document (W1).
  const otpRef = ref.collection("private").doc("otp");
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return {kind: "not-found"};

    const b = snap.data();
    if (b.driver?.driverId !== driverUid) return {kind: "permission-denied"};
    if (b.status !== "arrived") {
      return {kind: "wrong-status", status: b.status};
    }

    const otpSnap = await tx.get(otpRef);
    const o = otpSnap.exists ? otpSnap.data() : null;
    if (!o?.rideOtp) return {kind: "no-otp"};

    const now = Date.now();
    const lockedUntil = o.otpLockedUntil?.toMillis?.() || 0;
    if (now < lockedUntil) {
      return {
        kind: "locked",
        lockedUntil,
        remainingSec: Math.ceil((lockedUntil - now) / 1000),
      };
    }

    if (o.rideOtp !== otp) {
      const attempts = (o.otpFailedAttempts || 0) + 1;
      const update = {
        otpFailedAttempts: attempts,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      let locked = false;
      if (attempts >= OTP_MAX_ATTEMPTS) {
        update.otpLockedUntil = admin.firestore.Timestamp.fromMillis(
            now + OTP_LOCKOUT_MS,
        );
        update.otpFailedAttempts = 0;
        locked = true;
      }
      tx.update(otpRef, update);
      return {
        kind: "invalid-otp",
        attempts: locked ? OTP_MAX_ATTEMPTS : attempts,
        remaining: locked ? 0 : OTP_MAX_ATTEMPTS - attempts,
        locked,
      };
    }

    tx.update(ref, {
      status: "inProgress",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // The OTP is single-use: remove it once the trip has started.
    tx.delete(otpRef);
    return {kind: "ok"};
  });

  switch (result.kind) {
    case "ok":
      return {success: true};
    case "not-found":
      throw new HttpsError("not-found", "Booking not found.");
    case "permission-denied":
      throw new HttpsError("permission-denied", "Not your booking.");
    case "wrong-status":
      throw new HttpsError(
          "failed-precondition",
          `Cannot start trip from status ${result.status}.`,
      );
    case "no-otp":
      throw new HttpsError(
          "failed-precondition",
          "Ride OTP is not ready yet. Ask the rider to check their app.",
      );
    case "locked":
      throw new HttpsError(
          "resource-exhausted",
          `OTP locked. Retry in ${result.remainingSec}s.`,
          {lockedUntil: result.lockedUntil, remainingSec: result.remainingSec},
      );
    case "invalid-otp":
      throw new HttpsError("invalid-argument", "Invalid OTP.", {
        attempts: result.attempts,
        remaining: result.remaining,
        locked: result.locked,
      });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE AVAILABILITY CHECK
//
// Called by the client during email registration to check whether a mobile
// number is already in use. Client is unauthenticated at call time, so this
// runs with admin credentials. Returns { available: bool } only — never
// leaks the owning user's identity.
//
// enforceAppCheck (W3): without it this callable is an open oracle for
// enumerating which phone numbers have accounts. App Check limits callers
// to attested app installs (Play Integrity in release builds).
// ─────────────────────────────────────────────────────────────────────────────
exports.checkMobileAvailable = onCall({enforceAppCheck: true}, async (request) => {
  const raw = request.data?.mobile;
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "mobile is required.");
  }
  const mobile = raw.trim();
  if (mobile.length < 6 || mobile.length > 20) {
    throw new HttpsError("invalid-argument", "mobile has invalid length.");
  }

  const db = admin.firestore();
  const snap = await db
      .collection("users")
      .where("mobile", "==", mobile)
      .limit(1)
      .get();

  return {available: snap.empty};
});

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT DELETION (Google Play User Data policy)
//
// Deletes the caller's account and all associated PII. Runs with admin
// privileges because security rules intentionally forbid clients from
// deleting agreements and bookings. Bookings are financial records, so
// they are anonymized rather than deleted.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Commits Firestore writes in chunks below the 500-op batch limit.
 * @param {FirebaseFirestore.Firestore} db Firestore instance
 * @param {Array<{ref: FirebaseFirestore.DocumentReference, data: Object}>} ops
 *     update operations to apply
 */
async function _commitInChunks(db, ops) {
  const CHUNK = 400;
  for (let i = 0; i < ops.length; i += CHUNK) {
    const batch = db.batch();
    for (const {ref, data} of ops.slice(i, i + CHUNK)) {
      batch.update(ref, data);
    }
    await batch.commit();
  }
}

exports.deleteAccount = onCall({enforceAppCheck: true}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.auth.uid;
  const db = admin.firestore();
  logger.info("deleteAccount: starting for", uid);

  // 1. Vehicles owned by the user (recursiveDelete removes the documents/,
  //    schedules/, blocked_dates/ and settings/ subcollections too).
  const vehicles = await db
      .collection("vehicles").where("userId", "==", uid).get();
  for (const doc of vehicles.docs) {
    await db.recursiveDelete(doc.ref);
  }

  // 2. Agreements contain the owner's signature image — PII. Rules make
  //    them immutable for clients; the admin SDK bypasses rules.
  const agreements = await db
      .collection("agreements").where("userId", "==", uid).get();
  if (!agreements.empty) {
    const batch = db.batch();
    agreements.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // 3. Bookings are retained as financial records but stripped of PII,
  //    both where the user was the rider and where they were the driver.
  const riderBookings = await db
      .collection("bookings").where("userId", "==", uid).get();
  await _commitInChunks(db, riderBookings.docs.map((doc) => ({
    ref: doc.ref,
    data: {
      userName: "Deleted user",
      userPhone: admin.firestore.FieldValue.delete(),
      userReview: admin.firestore.FieldValue.delete(),
      accountDeleted: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  })));
  const driverBookings = await db
      .collection("bookings").where("driver.driverId", "==", uid).get();
  await _commitInChunks(db, driverBookings.docs.map((doc) => ({
    ref: doc.ref,
    data: {
      "driver.name": "Deleted driver",
      "driver.phone": admin.firestore.FieldValue.delete(),
      "driverReview": admin.firestore.FieldValue.delete(),
      "driverAccountDeleted": true,
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    },
  })));

  // 4. Live-location doc and the user doc (recursiveDelete removes the
  //    notifications/ and savedAddresses/ subcollections).
  await db.doc(`drivers/${uid}`).delete();
  await db.recursiveDelete(db.doc(`users/${uid}`));

  // 5. Storage files — best effort: a missing bucket (e.g. in the
  //    emulator) or transient error must not strand the deletion.
  try {
    const bucket = admin.storage().bucket();
    for (const prefix of [`users/${uid}/`, `vehicles/${uid}/`,
      `support/${uid}/`]) {
      await bucket.deleteFiles({prefix});
    }
  } catch (err) {
    logger.warn("deleteAccount: storage cleanup skipped:", err.message);
  }

  // 6. Finally the Auth account itself. Admin deletion does not require
  //    a recent client login. Tolerate the account already being gone.
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
  }

  logger.info("deleteAccount: completed for", uid);
  return {success: true};
});

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORT TICKETS (W4)
//
// Complaints and feedback are created here rather than by direct client
// writes so ticket IDs come from a transactional counter — the previous
// client-side scheme (timestamp % 9000) could collide under load.
// Rules deny client creates on complaints/ and feedbacks/.
// ─────────────────────────────────────────────────────────────────────────────
const TICKET_KINDS = {
  complaint: {collection: "complaints", prefix: "ZY", idField: "ticketId"},
  feedback: {collection: "feedbacks", prefix: "FB", idField: "feedbackId"},
};

exports.createSupportTicket = onCall({enforceAppCheck: true}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.auth.uid;
  const data = request.data || {};
  const kind = TICKET_KINDS[data.kind];
  if (!kind) {
    throw new HttpsError("invalid-argument", "kind must be complaint or feedback.");
  }

  // Server-side validation mirroring the old security-rules checks.
  const imageUrl = typeof data.imageUrl === "string" ? data.imageUrl : null;
  let payload;
  if (data.kind === "complaint") {
    const {subject, description, priority} = data;
    if (typeof subject !== "string" || subject.trim() === "" ||
        typeof description !== "string" || description.trim() === "" ||
        !["Low", "Medium", "High"].includes(priority)) {
      throw new HttpsError("invalid-argument", "Invalid complaint fields.");
    }
    payload = {
      userId: uid,
      subject: subject.trim(),
      description: description.trim(),
      priority,
      imageUrl,
      status: "Pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  } else {
    const {rating, message} = data;
    if (typeof rating !== "number" || rating < 1 || rating > 5 ||
        typeof message !== "string" || message.trim() === "") {
      throw new HttpsError("invalid-argument", "Invalid feedback fields.");
    }
    payload = {
      userId: uid,
      rating,
      message: message.trim(),
      imageUrl,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  const db = admin.firestore();
  const counterRef = db.collection("counters").doc("supportTickets");
  const now = new Date();
  const dateStr = now.getFullYear().toString() +
      String(now.getMonth() + 1).padStart(2, "0") +
      String(now.getDate()).padStart(2, "0");

  // Transactional counter → collision-free, monotonically increasing IDs.
  const ticketId = await db.runTransaction(async (tx) => {
    const counterSnap = await tx.get(counterRef);
    const seq = (counterSnap.data()?.[data.kind] || 0) + 1;
    tx.set(counterRef, {[data.kind]: seq}, {merge: true});

    const id = `${kind.prefix}-${dateStr}-${String(seq).padStart(4, "0")}`;
    const docRef = db.collection(kind.collection).doc();
    tx.set(docRef, {...payload, [kind.idField]: id});
    return id;
  });

  logger.info(`createSupportTicket: ${data.kind} ${ticketId} for`, uid);
  return {ticketId};
});

exports.seedVehicleCatalog = onRequest(async (req, res) => {
  // Restrict to POST from authorized admin calls only
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) {
    res.status(401).send("Unauthorized");
    return;
  }
  try {
    const token = authHeader.split("Bearer ")[1];
    const decoded = await admin.auth().verifyIdToken(token);
    const userDoc = await admin.firestore().collection("users").doc(decoded.uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
      res.status(403).send("Forbidden");
      return;
    }
  } catch (e) {
    res.status(401).send("Unauthorized");
    return;
  }
  const catalogData = {
    colors: [
      "White",
      "Silver",
      "Grey",
      "Black",
      "Blue",
      "Red",
      "Maroon",
      "Brown",
      "Beige",
      "Green",
      "Yellow",
      "Orange",
      "Purple",
      "Pink",
      "Gold",
    ],
    private: {
      "Maruti Suzuki": [
        "Alto K10",
        "S-Presso",
        "Celerio",
        "Wagon R",
        "Swift",
        "Dzire",
        "Baleno",
        "Ignis",
        "Fronx",
        "Brezza",
        "Ertiga",
        "XL6",
        "Jimny",
        "Grand Vitara",
        "Invicto",
        "e Vitara",
        "Eeco",
      ],
      "Tata": [
        "Tiago",
        "Tiago NRG",
        "Tiago EV",
        "Tigor",
        "Tigor EV",
        "Punch",
        "Punch EV",
        "Altroz",
        "Nexon",
        "Nexon EV",
        "Harrier",
        "Harrier EV",
        "Safari",
        "Safari EV",
        "Curvv",
        "Curvv EV",
      ],
      "Hyundai": [
        "Exter",
        "Grand i10 Nios",
        "i20",
        "i20 N Line",
        "Aura",
        "Venue",
        "Venue N Line",
        "Verna",
        "Creta",
        "Creta N Line",
        "Creta Electric",
        "Alcazar",
        "Tucson",
        "Ioniq 5",
      ],
      "Mahindra": [
        "Bolero",
        "Bolero Neo",
        "Bolero Neo Plus",
        "Thar",
        "Thar Roxx",
        "XUV300",
        "XUV 3XO",
        "Scorpio Classic",
        "Scorpio N",
        "XUV700",
        "XUV400 EV",
        "BE 6",
        "XEV 9e",
      ],
      "Kia": [
        "Sonet",
        "Seltos",
        "Carens",
        "Carens Clavis EV",
        "Syros",
        "Carnival",
        "EV6",
        "EV9",
      ],
      "Toyota": [
        "Glanza",
        "Urban Cruiser Taisor",
        "Rumion",
        "Urban Cruiser Hyryder",
        "Innova Crysta",
        "Innova HyCross",
        "Hilux",
        "Fortuner",
        "Camry",
        "Vellfire",
      ],
      "Honda": [
        "Amaze",
        "City",
        "City e:HEV",
        "Elevate",
      ],
      "MG": [
        "Comet EV",
        "Windsor EV",
        "ZS EV",
        "Astor",
        "Hector",
        "Hector Plus",
        "Gloster",
        "M9",
        "Cyberster",
      ],
      "Skoda": [
        "Kylaq",
        "Kushaq",
        "Slavia",
        "Kodiaq",
        "Superb",
        "Octavia RS",
      ],
      "Volkswagen": [
        "Taigun",
        "Virtus",
        "Tiguan",
      ],
      "Jeep": [
        "Compass",
        "Meridian",
        "Wrangler",
      ],
      "Renault": [
        "Kwid",
        "Triber",
        "Kiger",
      ],
      "Nissan": [
        "Magnite",
        "X-Trail",
      ],
      "Citroen": [
        "C3",
        "C3 Aircross",
        "Basalt",
        "eC3",
      ],
      "BYD": [
        "Atto 3",
        "e6",
        "Seal",
        "Sealion 7",
        "eMax 7",
      ],
      "Vinfast": [
        "VF 6",
        "VF 7",
        "VF 8",
        "VF 9",
      ],
      "Tesla": [
        "Model 3",
        "Model Y",
      ],
      "Force": [
        "Gurkha",
        "Gurkha 5-Door",
      ],
      "Luxury Brands": {
        "Mercedes-Benz": [
          "A-Class Limousine",
          "C-Class",
          "E-Class",
          "E-Class LWB",
          "S-Class",
          "Maybach S-Class",
          "EQS",
          "EQE",
          "GLA",
          "GLB",
          "GLC",
          "GLE",
          "GLS",
          "Maybach GLS",
          "EQB",
          "EQS SUV",
          "AMG GT",
          "G-Class",
        ],
        "BMW": [
          "2 Series Gran Coupe",
          "3 Series",
          "3 Series Gran Limousine",
          "5 Series",
          "5 Series LWB",
          "7 Series",
          "X1",
          "X3",
          "X4",
          "X5",
          "X6",
          "X7",
          "Z4",
          "i4",
          "i5",
          "i7",
          "iX",
          "iX1",
          "iX1 LWB",
        ],
        "Audi": [
          "A4",
          "A6",
          "A8 L",
          "Q3",
          "Q3 Sportback",
          "Q5",
          "Q7",
          "Q8",
          "e-tron",
          "e-tron GT",
          "RS Q8",
          "RS e-tron GT",
        ],
        "Volvo": [
          "C40 Recharge",
          "EX30",
          "EX40",
          "XC40",
          "XC60",
          "XC90",
          "S90",
        ],
        "Lexus": [
          "ES",
          "NX",
          "RX",
          "LM",
          "LX",
        ],
        "Jaguar Land Rover": [
          "Range Rover Evoque",
          "Range Rover Velar",
          "Range Rover Sport",
          "Range Rover",
          "Discovery Sport",
          "Discovery",
          "Defender",
          "Jaguar F-Pace",
          "Jaguar I-Pace",
        ],
        "Porsche": [
          "Macan",
          "Cayenne",
          "Cayenne Coupe",
          "Panamera",
          "Taycan",
          "911",
        ],
        "Maserati": [
          "Ghibli",
          "Levante",
          "Quattroporte",
          "Grecale",
        ],
        "Lamborghini": [
          "Huracan",
          "Urus",
          "Revuelto",
        ],
        "Ferrari": [
          "Roma",
          "Portofino",
          "SF90 Stradale",
          "296 GTB",
          "812 GTS",
          "Purosangue",
        ],
        "Bentley": [
          "Flying Spur",
          "Continental GT",
          "Bentayga",
        ],
        "Rolls-Royce": [
          "Ghost",
          "Phantom",
          "Cullinan",
          "Spectre",
        ],
      },
    },
    commercial: {
      // ALL PRIVATE VEHICLES (Convertible to Commercial Use - Yellow Plate)
      "Maruti Suzuki": [
        // Private models convertible to commercial
        "Alto K10",
        "S-Presso",
        "Celerio",
        "Wagon R",
        "Swift",
        "Dzire",
        "Baleno",
        "Ignis",
        "Fronx",
        "Brezza",
        "Ertiga",
        "XL6",
        "Jimny",
        "Grand Vitara",
        "Invicto",
        "e Vitara",
        "Eeco",
        // Commercial-specific variants
        "Super Carry",
        "Eeco Cargo",
      ],
      "Tata": [
        // Private models convertible to commercial
        "Tiago",
        "Tiago NRG",
        "Tiago EV",
        "Tigor",
        "Tigor EV",
        "Punch",
        "Punch EV",
        "Altroz",
        "Nexon",
        "Nexon EV",
        "Harrier",
        "Harrier EV",
        "Safari",
        "Safari EV",
        "Curvv",
        "Curvv EV",
        // Commercial-specific variants
        "Ace Gold",
        "Ace HT Plus",
        "Intra V10",
        "Intra V30",
        "Intra V50",
        "Yodha",
        "407 Gold SFC",
        "709g LPT",
        "Ultra EV",
        "Prima",
        "Signa 4825.C",
        "Starbus",
        "Starbus EV",
        "Winger",
        "Winger Tourist",
        "Magic Express",
      ],
      "Hyundai": [
        // Private models convertible to commercial
        "Exter",
        "Grand i10 Nios",
        "i20",
        "i20 N Line",
        "Aura",
        "Venue",
        "Venue N Line",
        "Verna",
        "Creta",
        "Creta N Line",
        "Creta Electric",
        "Alcazar",
        "Tucson",
        "Ioniq 5",
      ],
      "Mahindra": [
        // Private models convertible to commercial
        "Bolero",
        "Bolero Neo",
        "Bolero Neo Plus",
        "Thar",
        "Thar Roxx",
        "XUV300",
        "XUV 3XO",
        "Scorpio Classic",
        "Scorpio N",
        "XUV700",
        "XUV400 EV",
        "BE 6",
        "XEV 9e",
        // Commercial-specific variants
        "Jeeto",
        "Jeeto Plus",
        "Supro Profit Mini Truck",
        "Supro Profit Passenger",
        "Bolero Pik-Up",
        "Bolero Pik-Up Extra Long",
        "Bolero Camper",
        "Bolero Maxitruck Plus",
        "Furio 7",
        "Furio 11",
        "Furio 14",
        "Furio 17",
        "JAYO",
        "Blazo X 28",
        "Blazo X 35",
        "Blazo X 42",
        "Blazo X 49",
        "e-Alfa Mini",
        "e-Alfa Cargo",
        "Treo",
        "Treo Zor",
      ],
      "Kia": [
        // Private models convertible to commercial
        "Sonet",
        "Seltos",
        "Carens",
        "Carens Clavis EV",
        "Syros",
        "Carnival",
        "EV6",
        "EV9",
      ],
      "Toyota": [
        // Private models convertible to commercial
        "Glanza",
        "Urban Cruiser Taisor",
        "Rumion",
        "Urban Cruiser Hyryder",
        "Innova Crysta",
        "Innova HyCross",
        "Hilux",
        "Fortuner",
        "Camry",
        "Vellfire",
      ],
      "Honda": [
        // Private models convertible to commercial
        "Amaze",
        "City",
        "City e:HEV",
        "Elevate",
      ],
      "MG": [
        // Private models convertible to commercial
        "Comet EV",
        "Windsor EV",
        "ZS EV",
        "Astor",
        "Hector",
        "Hector Plus",
        "Gloster",
        "M9",
        "Cyberster",
      ],
      "Skoda": [
        // Private models convertible to commercial
        "Kylaq",
        "Kushaq",
        "Slavia",
        "Kodiaq",
        "Superb",
        "Octavia RS",
      ],
      "Volkswagen": [
        // Private models convertible to commercial
        "Taigun",
        "Virtus",
        "Tiguan",
      ],
      "Jeep": [
        // Private models convertible to commercial
        "Compass",
        "Meridian",
        "Wrangler",
      ],
      "Renault": [
        // Private models convertible to commercial
        "Kwid",
        "Triber",
        "Kiger",
      ],
      "Nissan": [
        // Private models convertible to commercial
        "Magnite",
        "X-Trail",
      ],
      "Citroen": [
        // Private models convertible to commercial
        "C3",
        "C3 Aircross",
        "Basalt",
        "eC3",
      ],
      "BYD": [
        // Private models convertible to commercial
        "Atto 3",
        "e6",
        "Seal",
        "Sealion 7",
        "eMax 7",
        // Commercial-specific variants
        "e6 Cargo",
        "T3 Electric Van",
      ],
      "Vinfast": [
        // Private models convertible to commercial
        "VF 6",
        "VF 7",
        "VF 8",
        "VF 9",
      ],
      "Tesla": [
        // Private models convertible to commercial
        "Model 3",
        "Model Y",
      ],
      "Force": [
        // Private models convertible to commercial
        "Gurkha",
        "Gurkha 5-Door",
        // Commercial-specific variants
        "Urbania",
        "Trax Cruiser",
        "Trax Kargo King",
        "Traveller 3050",
        "Traveller 3350",
        "Traveller 3700",
        "Traveller 4020",
        "Citiline School Bus",
      ],
      "Luxury Brands": {
        "Mercedes-Benz": [
          // Private models convertible to commercial
          "A-Class Limousine",
          "C-Class",
          "E-Class",
          "E-Class LWB",
          "S-Class",
          "Maybach S-Class",
          "EQS",
          "EQE",
          "GLA",
          "GLB",
          "GLC",
          "GLE",
          "GLS",
          "Maybach GLS",
          "EQB",
          "EQS SUV",
          "AMG GT",
          "G-Class",
        ],
        "BMW": [
          // Private models convertible to commercial
          "2 Series Gran Coupe",
          "3 Series",
          "3 Series Gran Limousine",
          "5 Series",
          "5 Series LWB",
          "7 Series",
          "X1",
          "X3",
          "X4",
          "X5",
          "X6",
          "X7",
          "Z4",
          "i4",
          "i5",
          "i7",
          "iX",
          "iX1",
          "iX1 LWB",
        ],
        "Audi": [
          // Private models convertible to commercial
          "A4",
          "A6",
          "A8 L",
          "Q3",
          "Q3 Sportback",
          "Q5",
          "Q7",
          "Q8",
          "e-tron",
          "e-tron GT",
          "RS Q8",
          "RS e-tron GT",
        ],
        "Volvo": [
          // Private models convertible to commercial
          "C40 Recharge",
          "EX30",
          "EX40",
          "XC40",
          "XC60",
          "XC90",
          "S90",
          // Commercial-specific variants
          "FM Series",
          "FMX Series",
          "B8R Coach",
          "B11R Coach",
          "9600 Bus",
        ],
        "Lexus": [
          // Private models convertible to commercial
          "ES",
          "NX",
          "RX",
          "LM",
          "LX",
        ],
        "Jaguar Land Rover": [
          // Private models convertible to commercial
          "Range Rover Evoque",
          "Range Rover Velar",
          "Range Rover Sport",
          "Range Rover",
          "Discovery Sport",
          "Discovery",
          "Defender",
          "Jaguar F-Pace",
          "Jaguar I-Pace",
        ],
        "Porsche": [
          // Private models convertible to commercial
          "Macan",
          "Cayenne",
          "Cayenne Coupe",
          "Panamera",
          "Taycan",
          "911",
        ],
        "Maserati": [
          // Private models convertible to commercial
          "Ghibli",
          "Levante",
          "Quattroporte",
          "Grecale",
        ],
        "Lamborghini": [
          // Private models convertible to commercial
          "Huracan",
          "Urus",
          "Revuelto",
        ],
        "Ferrari": [
          // Private models convertible to commercial
          "Roma",
          "Portofino",
          "SF90 Stradale",
          "296 GTB",
          "812 GTS",
          "Purosangue",
        ],
        "Bentley": [
          // Private models convertible to commercial
          "Flying Spur",
          "Continental GT",
          "Bentayga",
        ],
        "Rolls-Royce": [
          // Private models convertible to commercial
          "Ghost",
          "Phantom",
          "Cullinan",
          "Spectre",
        ],
      },
      // COMMERCIAL-ONLY VEHICLES
      "Ashok Leyland": [
        "Dost",
        "Dost +",
        "Dost Strong",
        "BADA DOST",
        "BADA DOST i2",
        "BADA DOST i4",
        "Partner",
        "MiTR",
        "Ecomet",
        "Boss",
        "AVTR",
        "Captain",
        "Circuit Electric Bus",
        "Lynx Electric Bus",
      ],
      "Eicher": [
        "Pro 1049",
        "Pro 2049",
        "Pro 2059",
        "Pro 2095 XP",
        "Pro 3015",
        "Pro 6028T",
        "Pro 6031T",
        "Pro 8049",
        "Skyline Pro Bus",
        "Starline Bus",
        "Eicher Electric Truck",
      ],
      "BharatBenz": [
        "1617R Truck",
        "1917R Truck",
        "2823R Tipper",
        "3123R Tipper",
        "Staff Bus 917",
        "School Bus 917",
        "Tourist Bus 1623",
      ],
      "Bajaj": [
        "RE Compact",
        "RE Optima",
        "RE Maxima Z",
        "RE Maxima Cargo",
        "Ape HT Auto",
        "Ape Xtra LD",
        "Ape Xtra LDX",
      ],
      "Piaggio": [
        "Ape Auto",
        "Ape City",
        "Ape Xtra LDX",
        "Porter 700",
        "Porter 1000",
        "Ape E-City",
        "Ape E-Xtra FX",
      ],
      "Isuzu": [
        "D-Max V-Cross",
        "D-Max S-Cab",
        "D-Max Regular Cab",
      ],
      "OSM": [
        "Rage+",
        "Stream",
      ],
      "Euler Motors": [
        "HiLoad EV",
      ],
      "Altigreen": [
        "NeEV Cargo",
        "NeEV HD",
      ],
      "Omega Seiki": [
        "Rage+ Frost",
        "Rage+ Tipper",
      ],
      "Montra Electric": [
        "Rhino EV",
      ],
      "Scania": [
        "P Series",
        "G Series",
        "R Series",
        "Touring Coach",
        "Intercity Bus",
      ],
      "Daimler India": [
        "BharatBenz 914R",
        "BharatBenz 1215R",
      ],
      "SML Isuzu": [
        "Sartaj GS",
        "Supreme BS-VI",
      ],
      "Agricultural": {
        "Mahindra Tractors": [
          "275 DI TU",
          "475 DI",
          "575 DI",
          "Arjun Novo 605 DI",
          "Arjun Ultra 1",
          "Yuvo Tech+ 415",
          "OJA 3136",
        ],
        "Swaraj": [
          "735 FE",
          "744 FE",
          "843 XM",
          "855 FE",
        ],
        "Sonalika": [
          "DI 35 RX",
          "DI 47 RX",
          "DI 60 RX",
          "DI 750 III",
          "Tiger 55",
          "Tiger 65",
        ],
        "Eicher Tractors": [
          "242 NH",
          "380 Super Plus",
          "485 Super Plus",
          "551 Super Plus",
          "5660 Super DI",
        ],
        "John Deere": [
          "5050 D",
          "5055 E",
          "5075 E",
          "5310",
        ],
        "New Holland": [
          "3230 NX",
          "3630 TX Super Plus",
          "5620 TX Plus",
        ],
        "Massey Ferguson": [
          "1035 DI Maha Shakti",
          "7250 DI Power Up",
          "9500",
        ],
        "Kubota": [
          "MU4501 2WD",
          "MU5501 2WD",
          "Neostar A211N",
        ],
      },
    },
  };

  await admin
      .firestore()
      .collection("vehicleCatalog")
      .doc("india2025")
      .set(catalogData);

  res.status(200).send("Vehicle catalog seeded successfully.");
});
