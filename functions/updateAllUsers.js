// Update database user_status field added for all user..

const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(
      require("./zyppiride-2025-firebase-adminsdk-fbsvc-8888785e38.json"),
  ),
});

const db = admin.firestore();

async function addUserStatusField() {
  const usersRef = db.collection("users");
  const snapshot = await usersRef.get();

  let count = 0;
  const batch = db.batch();

  snapshot.forEach((doc) => {
    const userRef = usersRef.doc(doc.id);
    batch.update(userRef, {user_status: true}); // Add or overwrite field
    count++;
  });

  await batch.commit();
  console.log(`✅ Successfully updated ${count} users with user_status: true`);
}

addUserStatusField().catch(console.error);
