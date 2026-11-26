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
initializeFirestore(app, { preferRest: true, ignoreUndefinedProperties: true });
// Load only after the explicit Admin credential is configured.
const handlers = await import('./backend.js');
const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? 'https://tslcgavpkujkfexzmisk.supabase.co').replace(/\/+$/, '');
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim();

Deno.serve(createHandler({
  ipHashSalt: Deno.env.get('IP_HASH_SALT') ?? 'food-insight-ip-v1',
  authenticate: async token => {
    const decoded = await getAuth(app).verifyIdToken(token, true);
    return { uid: decoded.uid, token: decoded };
  },
  attest: async token => {
    const decoded = await getAppCheck(app).verifyToken(token);
    const allowed = ['1:579993459207:android:10cf6387d86c313697e8a2'];
    // Optional, explicit QA registration; valid App Check remains mandatory.
    const qaAppId = Deno.env.get('QA_FIREBASE_APP_ID');
    if (qaAppId) allowed.push(qaAppId);
    if (!allowed.includes(decoded.appId)) throw new Error('Wrong app');
    return { appId: decoded.appId };
  },
  checkIpRateLimit: async ipHash => {
    if (!supabaseServiceKey) return { allowed: true };
    try {
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/check_ip_rate_limit`, {
        method: 'POST',
        headers: {
          apikey: supabaseServiceKey,
          Authorization: `Bearer ${supabaseServiceKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ p_ip_hash: ipHash, p_limit: 30 }),
        signal: AbortSignal.timeout(3000),
      });
      if (!response.ok) return { allowed: true };
      const body = await response.json() as { allowed?: boolean; retryAfterSeconds?: number };
      return {
        allowed: body.allowed !== false,
        retryAfterSeconds: body.retryAfterSeconds,
      };
    } catch {
      return { allowed: true };
    }
  },
  // The shared handlers read only data/auth/app/ipHash, populated above by this bridge.
  invoke: (name, request) => {
    const handler = handlers[name as keyof typeof handlers];
    return (handler as { run: (req: unknown) => Promise<unknown> }).run(request);
  },
  invokeStream: async (name, request) => {
    if (name !== 'aiTask' || typeof handlers.aiTaskStream !== 'function') {
      throw { code: 'invalid-argument', message: 'Streaming is unavailable for this operation.' };
    }
    return handlers.aiTaskStream(request);
  },
}));
