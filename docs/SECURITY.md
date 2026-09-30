# Security model and verification

## Controls in source

- Firebase Auth identifies callers; v2 product, AI and deletion callables require App Check. Flutter uses the debug provider in debug and Play Integrity in release.
- Firestore clients can read canonical products only when authenticated, and cannot create, update or delete them. `config/featureFlags` and `users/{uid}/aiUsage` are read-only to clients. User and legacy paths are owner scoped.
- Firebase Storage canonical product assets are server writable only. User assets require owner scope, image MIME and a 10 MB cap. Supabase private buckets use RLS with the Firebase UID in the verified JWT and a deletion guard.
- Groq and Supabase service role credentials exist only as Firebase Functions secrets. Client configuration contains public Firebase/Supabase values. Android release disables cleartext traffic and Android backup; release builds require a private keystore.
- Backend validates barcodes, task type, request size, profile fields, AI output and quotas. It does not log health content or provider prompts. Crashlytics sends reduced error identifiers and stack traces, without exception messages.

## Local evidence

`security-tests/rules.test.cjs` ran against Firestore and Storage emulators with Java 25: five tests passed, including cross-account denial, canonical product poisoning denial, quota and feature switch write denial, and storage type/size/owner checks. Backend unit tests cover normalization and output validation. This does not prove deployed rules or live Supabase RLS.

## Required live checks

Verify the Firebase project in `.firebaserc`, deploy rules and functions, and inspect effective rules in Console. Apply Supabase migrations before enabling sign-in, and test a second UID against every current table and both image buckets. Register App Check and release SHA fingerprints; verify accepted and rejected callable requests on a Play-installed build. Restrict and rotate old secrets, deploy the retired Supabase AI proxy response, then remove obsolete deployed functions. Review `npm audit` transitive moderate findings and limit backend service account roles where possible.

Never commit `frontend/android/key.properties`, a keystore, service-account JSON, Groq key, Supabase service role key, App Check debug token, or crash symbol archive. Firebase client API keys are public identifiers, but project/API restrictions still matter.
