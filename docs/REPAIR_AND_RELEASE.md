# Account isolation and Android repair — 18 September 2026

> Historical repair record. The current architecture and release steps are in
> [ARCHITECTURE.md](ARCHITECTURE.md) and [RELEASE.md](RELEASE.md). In particular,
> per-user Groq keys and `AI_PROXY_URL` were removed from the new beta client;
> AI now uses the Firebase `aiTask` callable. The release APK described below
> predates the current `1.0.2+3` app bundle work.

## Current architecture

Firebase Auth supplies a stable string UID for email and Google accounts. Supabase
accepts Firebase JWTs only from `food-insight-scanner-app`. Profiles, scans, diet
entries, shopping items, meal plans, chat messages and activity logs are stored in
separate Supabase tables, keyed by `(user_id, id)`. Both queries and database RLS
enforce ownership. Firebase UIDs are not cast to UUIDs or replaced with new IDs.

The SQLite account cache uses the same compound key. A durable outbox preserves
offline changes through logout. Retries upsert the same ID; deletion tombstones
prevent offline deletes from reappearing during refresh. In-flight operations
capture an account revision and discard results when the session changes.

Supabase was inspected before migration: no public application tables or policies
existed, only the legacy uploads bucket. SQL migrations in `supabase/migrations`
create the new schema and protect both upload buckets without deleting objects.
The client supplies refreshed Firebase tokens to database and storage requests.
Policies check the verified JWT issuer, audience and subject even when Firebase
tokens have no Postgres `role` claim. A publishable key alone cannot access rows.

On the owner's login, existing Firestore records and UID-owned legacy SQLite rows
are imported without deleting originals. Ownerless `__local__` records and global
profile preferences are not assigned to arbitrary accounts. No bulk migration of
existing users has been claimed: this migration runs per owner when they log in.

## Repairs

- Removed duplicate Android plugin registration and serialized Firebase startup/retry.
- Registered the existing release certificate's SHA-1 and SHA-256 in Firebase and
  refreshed `google-services.json`. Release builds use `android/key.properties`.
- Profile and screen results cannot overwrite another account after an async load.
- Dashboard uses the same stored scans/diet data as full history, listens for
  changes and normalizes cloud timestamps. Offline records survive logout.
- AI service was truncated in the starting checkout. Restored all called methods,
  JSON mode, response validation, timeouts, meal-plan totals and photo input.
- India is explicit; Settings offers regional cuisine preferences. All AI
  features receive the full profile, including diet restrictions and allergies.
- Saved plans, chat history and activity are scoped to UID and synced.
- Fixed shopping list IDs and added its missing add-item action.

## AI configuration

This build retains the existing per-user Groq key option in Settings. Keys are not
compiled into the APK. An unowned key from the old global preferences is not
silently transferred to another account: enter it once for the correct account.
`AI_PROXY_URL` remains available for a separately configured authenticated proxy.
No Firebase AI functions were deployed on this project during inspection.

## Verification and release

`flutter test` exercises account separation, stable IDs, logout cache restoration,
sync acknowledgement races, deletion tombstones, cross-owner imports, AI JSON
validation and regional profile persistence.

`python tools/verify_cloud.py --run-live` creates two temporary Firebase accounts,
tests repeated login/UID stability, all seven tables' RLS, cross-owner deletion and
private image upload/signing. It deletes its own fixtures and accounts afterward.

Verified on this checkout: all nine regression tests passed, and the live
two-account database/storage checks passed with their fixtures removed. Static
analysis reports no errors or warnings; informational style lints remain.

Native Google sign-in, camera and Health Connect still require a device smoke
test. No Android device was connected; attempts to download an emulator failed
with network resets. Live AI output also requires a configured per-user key;
JSON validation and regional context were tested without sending model requests.

Run `tools/build_release.ps1` for signed APKs for arm64-v8a, armeabi-v7a and x86_64.
Dart obfuscation and R8 shrinking are enabled. Preserve `symbols/` and
`r8-mapping.txt` privately for crash symbolication; don't distribute them with APKs.

Release 1.0.1 was built successfully in `releases/1.0.1/`. All three APKs passed
`apksigner verify`, match the registered release certificate and contain only
their respective native ABI. Manifest checks confirmed Android 8.0 minimum
(API 26), target API 36 and version 1.0.1. SHA-256 checksums accompany the APKs.

Reference: [Supabase Firebase integration](https://supabase.com/docs/guides/auth/third-party/firebase-auth),
[Flutter Android releases](https://docs.flutter.dev/deployment/android),
[Flutter obfuscation](https://docs.flutter.dev/deployment/obfuscate),
[Groq JSON mode](https://console.groq.com/docs/structured-outputs).
