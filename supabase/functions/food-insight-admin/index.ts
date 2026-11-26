import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import { adminAction } from "./backend.js";
import { buildAllowedOrigins, createAdminEdgeHandler } from "./handler.ts";

function ensureFirebaseAdmin(): void {
  if (getApps().length > 0) return;
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
  if (!raw.trim()) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON secret is missing.");
  }
  const serviceAccount = JSON.parse(raw);
  initializeApp({ credential: cert(serviceAccount) });
}

const allowedOrigins = Array.from(buildAllowedOrigins(Deno.env.get("ADMIN_ALLOWED_ORIGINS") ?? ""));

const handler = createAdminEdgeHandler({
  allowedOrigins,
  verifyAdminToken: async (idToken) => {
    ensureFirebaseAdmin();
    // Enforce revocation check so disabled/revoked admins lose access immediately.
    const decoded = await getAuth().verifyIdToken(idToken, true);
    return {
      uid: decoded.uid,
      token: decoded as unknown as Record<string, unknown>,
    };
  },
  runAdminAction: (req) => adminAction.run(req),
});

Deno.serve(handler);
