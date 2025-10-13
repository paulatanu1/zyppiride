const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(
      require("./zyppiride-2025-firebase-adminsdk-fbsvc-8888785e38.json"),
  ),
});

const db = admin.firestore();

// Enable offline persistence for local caching (optional, for emulator testing)
db.settings({ignoreUndefinedProperties: true});

async function addUserStatusField() {
  const usersRef = db.collection("users");
  const snapshot = await usersRef.get();
  const batchSize = 500; // Firestore batch limit
  let count = 0;
  let batch = db.batch();
  const startTime = new Date().toISOString(); // Timestamp for logging

  try {
    // Use for...of to handle async operations sequentially
    for (const [index, doc] of snapshot.docs.entries()) {
      const userRef = usersRef.doc(doc.id);
      const userData = doc.data();

      // Only add is_admin if it doesn't exist or is undefined
      if (!userData.hasOwnProperty("is_admin")) {
        batch.update(userRef, {is_admin: false});
        count++;
      }

      // Commit batch every 500 documents or at the last document
      if (count % batchSize === 0 || index === snapshot.docs.length - 1) {
        console.log(`Processing batch with ${count} updates...`);
        await batch.commit();
        batch = db.batch(); // Start new batch
      }
    }

    console.log(
        `✅ Successfully updated ${count} users with is_admin: false at ${startTime}`,
    );
  } catch (error) {
    console.error(`❌ Error updating users: ${error.message}`);
    throw error; // Re-throw for external catch if needed
  }
}

// Wrap in an immediately invoked async function to handle top-level await
(async () => {
  try {
    await addUserStatusField();
  } catch (error) {
    console.error(`❌ Script failed: ${error.message}`);
    process.exit(1); // Exit with error code
  }
})();
