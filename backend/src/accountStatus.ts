import { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * Verifies an authenticated user is neither mid-deletion nor suspended.
 */
export async function assertAccountActive(db: Pick<Firestore, "doc">, uid: string): Promise<void> {
  const [deletionSnap, suspensionSnap] = await Promise.all([
    db.doc(`accountDeletionGuards/${uid}`).get(),
    db.doc(`userSuspensions/${uid}`).get(),
  ]);
  if (deletionSnap.exists) {
    throw new HttpsError("permission-denied", "Account deletion is in progress.");
  }
  const suspension = suspensionSnap.data();
  if (suspensionSnap.exists && suspension?.active !== false) {
    throw new HttpsError("permission-denied", "This account has been suspended.");
  }
}
