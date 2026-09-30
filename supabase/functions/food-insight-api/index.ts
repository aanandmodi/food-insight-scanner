import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getAppCheck } from 'firebase-admin/app-check';
import { initializeFirestore } from 'firebase-admin/firestore';
import { createHandler } from './handler.ts';

const credentials = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '{}');
if (credentials.project_id !== 'food-insight-scanner-app') throw new Error('Backend credentials are not configured.');
const app = initializeApp({ credential: cert(credentials), projectId: credentials.project_id,
  storageBucket: 'food-insight-scanner-app.firebasestorage.app' });
// REST transport avoids gRPC native dependencies in the Edge runtime.
initializeFirestore(app, { preferRest: true });
// Load only after the explicit Admin credential is configured.
const handlers = await import('./backend.js');
Deno.serve(createHandler({
  authenticate: async token => {
    const decoded = await getAuth(app).verifyIdToken(token, true);
    return { uid: decoded.uid, token: decoded };
  },
  attest: async token => {
    const decoded = await getAppCheck(app).verifyToken(token);
    if (decoded.appId !== '1:579993459207:android:10cf6387d86c313697e8a2') throw new Error('Wrong app');
    return { appId: decoded.appId };
  },
  // The shared handlers read only data/auth/app, populated above by this bridge.
  invoke: (name, request) => {
    const handler = handlers[name as keyof typeof handlers];
    return handler.run(request as unknown as Parameters<typeof handler.run>[0]);
  },
}));
