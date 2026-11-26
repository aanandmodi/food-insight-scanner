import { cert, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { initializeFirestore } from "firebase-admin/firestore";

import { buildAllowedOrigins, createAdminEdgeHandler } from "./handler.ts";

const credentials = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "{}",
);
if (credentials.project_id !== "food-insight-scanner-app") {
  throw new Error("Backend credentials are not configured.");
}

const app = initializeApp({
  credential: cert(credentials),
  projectId: credentials.project_id,
  storageBucket: "food-insight-scanner-app.firebasestorage.app",
});
// REST transport avoids gRPC native dependencies in the Edge runtime.
initializeFirestore(app, {
  preferRest: true,
  ignoreUndefinedProperties: true,
} as Parameters<typeof initializeFirestore>[1]);

// Load only after the explicit Admin credential and REST Firestore are configured.
const { adminAction } = await import("./backend.js");

const allowedOrigins = Array.from(
  buildAllowedOrigins(Deno.env.get("ADMIN_ALLOWED_ORIGINS") ?? ""),
);

const handler = createAdminEdgeHandler({
  allowedOrigins,
  verifyAdminToken: async (idToken) => {
    // Enforce revocation check so disabled/revoked admins lose access immediately.
    const decoded = await getAuth(app).verifyIdToken(idToken, true);
    return {
      uid: decoded.uid,
      token: decoded as unknown as Record<string, unknown>,
    };
  },
  runAdminAction: (req) => adminAction.run(req),
});

Deno.serve(handler);
