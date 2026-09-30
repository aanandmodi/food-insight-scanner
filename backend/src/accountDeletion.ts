import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";

import { defineSecret } from "firebase-functions/params";
import { onCall, HttpsError } from "firebase-functions/v2/https";

if (!getApps().length) initializeApp();
export const supabaseAdminKey = defineSecret("SUPABASE_SERVICE_ROLE_KEY");
const supabaseUrl = "https://tslcgavpkujkfexzmisk.supabase.co";

async function supabaseRequest(path: string, body: unknown, method = "POST", optionalMissingBucket = false): Promise<any> {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method, headers: { apikey: supabaseAdminKey.value(), Authorization: `Bearer ${supabaseAdminKey.value()}`,
      "Content-Type": "application/json" }, body: JSON.stringify(body), signal: AbortSignal.timeout(15000),
  });
  if (optionalMissingBucket && response.status === 404) return [];
  if (!response.ok) throw new Error("Account storage cleanup must be retried");
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

async function deleteStorageFolder(bucket: string, prefix: string): Promise<void> {
  // Always restart at offset zero after deleting a page; advancing would skip objects.
  while (true) {
    const objects = await supabaseRequest(`/storage/v1/object/list/${bucket}`,
      { prefix, limit: 100, offset: 0, sortBy: { column: "name", order: "asc" } }, "POST", true);
    if (!Array.isArray(objects)) throw new Error("Unexpected storage response");
    if (!objects.length) return;
    const paths: string[] = [];
    for (const object of objects) {
      if (typeof object.name !== "string" || object.name.includes("/") || object.name === "..") throw new Error("Invalid storage path");
      const path = `${prefix}/${object.name}`;
      if (object.id == null) await deleteStorageFolder(bucket, path);
      else paths.push(path);
    }
    if (paths.length) await supabaseRequest(`/storage/v1/object/${bucket}`, { prefixes: paths }, "DELETE");
  }
}

/** Idempotent, retryable cleanup, shared by in-app deletion and the Auth trigger. */
export async function cleanupUserData(uid: string): Promise<void> {
  if (!uid || uid.length > 128 || uid.includes("/")) throw new Error("Invalid owner");
  const db = getFirestore();
  // Reject offline/stale JWT writes before removing any personal records.
  await db.doc(`accountDeletionGuards/${uid}`).set({ deleting: true });
  // Atomically blocks still-valid Firebase JWTs at RLS and deletes all account rows.
  await supabaseRequest("/rest/v1/rpc/delete_food_insight_user", { owner_uid: uid });
  for (const bucket of ["food-insight-private", "food-insight-uploads"]) {
    await deleteStorageFolder(bucket, `users/${uid}`);
  }
  for (const collection of ["users", "scan_history", "diet_log", "shopping_list", "activity_logs"]) {
    await db.recursiveDelete(db.collection(collection).doc(uid));
  }
  try {
    await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
  } catch (error: any) {
    // A never-provisioned bucket contains no user assets. Permission and network
    // failures must still block deletion; never silently abandon existing files.
    if (error?.code !== 404) throw error;
  }
}

export const requestAccountDeletion = onCall({ region: "asia-south1", enforceAppCheck: true,
  timeoutSeconds: 540, secrets: [supabaseAdminKey], maxInstances: 3 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to delete your account.");
  const anonymous = request.auth.token.firebase?.sign_in_provider === "anonymous";
  if (!anonymous && Date.now() / 1000 - request.auth.token.auth_time > 300) {
    throw new HttpsError("failed-precondition", "Please sign in again before deleting your account.");
  }
  try {
    await cleanupUserData(request.auth.uid);
    await getAuth().deleteUser(request.auth.uid);
    return { deleted: true };
  } catch {
    // Do not delete Auth until all user stores acknowledge cleanup. Retrying is safe.
    throw new HttpsError("unavailable", "Account cleanup could not finish. Please retry deletion.");
  }
});
