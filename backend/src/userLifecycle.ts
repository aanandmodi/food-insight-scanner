import { cleanupUserData } from "./accountDeletion";
import * as functions from "firebase-functions/v1";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";


if (!getApps().length) {
  initializeApp();
}

/**
 * Cloud Function triggered automatically when a new user signs up in Firebase Auth.
 * Initializes default user profile metrics and goal settings in Firestore.
 */
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const db = getFirestore();
  const userRef = db.collection("users").doc(user.uid);

  try {
    const doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        uid: user.uid,
        email: user.email || "",
        displayName: user.displayName || "New User",
        photoURL: user.photoURL || "",
        createdAt: FieldValue.serverTimestamp(),
        dailyCalorieGoal: 2000,
        dailyCarbGoal: 250,
        dailyProteinGoal: 100,
        dailyFatGoal: 65,
        dailyStepGoal: 10000,
        profileCompleted: false,
      });
      console.log("Initialized account profile");
    }
  } catch (error) {
    throw new Error("Account initialization failed");
  }
});

/**
 * Cloud Function triggered automatically when a user account is deleted in Firebase Auth.
 * Performs cascading cleanup of all Firestore documents under users/{userId} and Firebase Storage files.
 */
export const onUserDeleted = functions.runWith({
  failurePolicy: true, timeoutSeconds: 540, secrets: ["SUPABASE_SERVICE_ROLE_KEY"],
}).auth.user().onDelete(async (user) => {
  // Throw on failure so event delivery retries. Never log personal data.
  await cleanupUserData(user.uid);
});
