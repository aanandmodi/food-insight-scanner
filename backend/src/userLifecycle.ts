import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Cloud Function triggered automatically when a new user signs up in Firebase Auth.
 * Initializes default user profile metrics and goal settings in Firestore.
 */
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(user.uid);

  try {
    const doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        uid: user.uid,
        email: user.email || "",
        displayName: user.displayName || "New User",
        photoURL: user.photoURL || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dailyCalorieGoal: 2000,
        dailyCarbGoal: 250,
        dailyProteinGoal: 100,
        dailyFatGoal: 65,
        dailyStepGoal: 10000,
        profileCompleted: false,
      });
      console.log(`Initialized Firestore profile for user: ${user.uid}`);
    }
  } catch (error) {
    console.error(`Error initializing user profile for ${user.uid}:`, error);
  }
});

/**
 * Cloud Function triggered automatically when a user account is deleted in Firebase Auth.
 * Performs cascading cleanup of all Firestore documents under users/{userId} and Firebase Storage files.
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const db = admin.firestore();
  const storage = admin.storage();
  const userId = user.uid;

  console.log(`Starting cascading data deletion for user: ${userId}`);

  try {
    // 1. Delete user document and subcollections in Firestore
    const userRef = db.collection("users").doc(userId);
    await db.recursiveDelete(userRef);

    // 2. Delete legacy collections if any
    const legacyCollections = ["scan_history", "diet_log", "shopping_list", "activity_logs"];
    for (const col of legacyCollections) {
      const docRef = db.collection(col).doc(userId);
      await db.recursiveDelete(docRef);
    }

    // 3. Delete files in Firebase Storage under users/{userId}/
    try {
      const bucket = storage.bucket();
      await bucket.deleteFiles({ prefix: `users/${userId}/` });
      console.log(`Deleted Storage files for user: ${userId}`);
    } catch (stErr) {
      console.warn(`Storage file deletion warning for ${userId}:`, stErr);
    }

    console.log(`Successfully completed cascading deletion for user: ${userId}`);
  } catch (error) {
    console.error(`Error deleting data for user ${userId}:`, error);
  }
});
