// Local-only helper script to grant or revoke Firebase Admin role claim (`role: 'admin'`)
// using local Firebase Admin service-account credentials supplied at runtime via ENV or CLI flag.
// Never store service-account JSON inside the repository.
import fs from 'node:fs';
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const args = process.argv.slice(2);
const readArg = (name) => {
  const idx = args.indexOf(name);
  return idx >= 0 && idx + 1 < args.length ? args[idx + 1] : '';
};

const email = readArg('--email').trim();
const uid = readArg('--uid').trim();
const revoke = args.includes('--revoke');
const keyFile = readArg('--service-account').trim();

const rawJson = keyFile
  ? fs.readFileSync(keyFile, 'utf8')
  : (process.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? '');

if (!rawJson.trim()) {
  console.error('Provide FIREBASE_SERVICE_ACCOUNT_JSON in env or --service-account <path-to-json>.');
  process.exit(1);
}
if (!email && !uid) {
  console.error('Usage: node tools/set_admin_claim.mjs --email <owner-email> [--service-account <path>] [--revoke]');
  process.exit(1);
}

const creds = JSON.parse(rawJson);
if (creds.project_id !== 'food-insight-scanner-app') {
  console.error(`Unexpected project_id "${creds.project_id}"; expected food-insight-scanner-app.`);
  process.exit(1);
}

initializeApp({ credential: cert(creds), projectId: creds.project_id });
const auth = getAuth();
const user = uid ? await auth.getUser(uid) : await auth.getUserByEmail(email);
const existing = user.customClaims ?? {};
const nextClaims = { ...existing };

if (revoke) {
  delete nextClaims.role;
  delete nextClaims.admin;
} else {
  nextClaims.role = 'admin';
  nextClaims.admin = true;
}

await auth.setCustomUserClaims(user.uid, nextClaims);
console.log(
  revoke
    ? `Revoked admin claims for ${user.uid} (${user.email ?? 'no-email'}). User must sign out and back in.`
    : `Granted role=admin claim for ${user.uid} (${user.email ?? 'no-email'}). Sign out and sign back in on the Admin Portal to refresh your ID token.`,
);
