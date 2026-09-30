# FOOD INSIGHT BETA READINESS REPORT

Updated 30 September 2026. This is an evidence record, not a declaration that every live-service/Play gate is complete.

## 1. Build Status

Flutter 3.29.3 / Dart 3.7.2; Android JDK 17. Release version `1.0.2+2003`. A prior signed AAB built successfully; a new build with the latest changes is being verified. See the final artifact record below before distributing.

## 2. Critical Bugs Fixed

Replaced the broken backend client, normalized sodium, removed false safety claims and invented alternatives, isolated owner caches, made meal saves idempotent, required review of AI meal estimates, and fixed navigation when AI is disabled.

## 3. Security Changes

Canonical products are read-only to clients. UID ownership applies to current/legacy Firestore records and Supabase RLS. Deletion guards prevent stale-token recreation. Backend validates Firebase Auth, App Check, request size, AI output, daily and burst quotas. No provider secret is compiled into Flutter.

## 4. Firebase Changes

Firestore rules and Hosting deployed successfully. Release SHA-1/SHA-256 and App Check Play Integrity configuration exist. The project remains on Spark (`billingEnabled: false`). No paid Functions or Storage provisioning was performed.

## 5. AI Architecture Changes

Shared TypeScript handlers compile for Firebase Functions or Supabase Free Edge. The mobile default is the latter. Server-only Groq key, task allowlist, bounded profile fields, validated JSON and attempts-based quotas. Global cap: 200 attempts/day and 10/minute. AI remains off unless server flags enable it. **The new Edge deployment still needs Supabase account access.**

## 6. Food Fit Engine

Deterministic score, confidence, positives, cautions, conflicts and unknowns. Confirmed allergens suppress the numeric score. Dietary/trace conflict caps apply after nutrient adjustments. AI may explain the result but does not calculate it.

## 7. Allergen Safety Changes

Structured allergens, trace tags and ingredient synonyms produce confirmed conflict, possible trace, no detected conflict or insufficient information. Physical package verification remains essential.

## 8. Nutrition Data Fixes

Explicit per-100g keys, sodium in mg, bounded values, missing values preserved as unknown, grams-based portion scaling. Dashboard no longer infers unknown fat from calories or equates carbohydrate intake with sugar. Manual meal entry distinguishes blank nutrients from entered zeros.

## 9. UI/UX Improvements

Existing warm-white/green identity retained. Scanner errors and manual barcode validation improved. Meal entry supports editable AI estimates, manual fallback and protected saves. Settings exposes legal pages, app version, optional diagnostics/analytics, activity control and deletion confirmation. Dead/fake features are hidden.

## 10. Accessibility

Automated safety-card tests at text scales 1.0/1.3/1.6/2.0; full product details at 1.0/2.0; scanner failure at 320×568 with 2.0 text. Dialogs scroll. Physical TalkBack and complete screen coverage remain separate checks.

## 11. Performance

Shared product cache, local SQLite reads/outbox, bounded API timeouts and history, release shrinking and obfuscation. Camera lifecycle handling is present. No low-end-device frame-time claim is made without a measured device run.

## 12. Testing

33 Flutter tests (31 full-suite pass plus two added product-screen cases passing); 10 backend unit tests; 11 Firestore/Storage/backend emulator tests; 9 Edge HTTP/runtime tests. Emulator checks include quota races, kill switch, malformed AI, cache normalization and deletion guards. Live Supabase/Groq/account cleanup must be verified after deployment.

## 13. CI

GitHub Actions includes analyze/test, backend/Edge bundle checks, rules/backend emulators, and release compilation with an ephemeral CI certificate. That certificate is not the production upload key and the CI AAB is never distributed. Private-repository usage must stay within included Actions minutes. Hosted run results are recorded after pushing.

## 14. Android Release Configuration

Application ID `com.food_insight_scanner.app`; min SDK 26; target/compile SDK 36. Cleartext networking/backup disabled. Existing private release key retained. AD_ID permission explicitly removed. Health Connect privacy rationale is registered for Android 13 and 14+ and works from a bundled copy of the published policy.

## 15. Play Store Preparation

Public privacy, terms and deletion URLs are live under `https://food-insight-scanner-app.web.app/`. Data safety, health-use, signing and closed-testing worksheets exist. Store declarations, listing and Play approval require the owner/account holder.

## 16. Features Disabled / Feature-Flagged

Unverified alternatives, OCR, image AI, notifications, fake ratings and billing are off. AI chat/plans require server flags. Analytics is opt-in and sends enum event names only, without account IDs, barcodes, meals, allergies or chat content; SDK app/device identifiers are disclosed.

## 17. Remaining Known Risks

New Edge backend and deletion migration are not yet live-verified; the old proxy must be retired. Two moderate upstream Node dependency audit findings remain in the legacy Storage SDK dependency chain. Play-installed sign-in/attestation, full deletion, physical camera/health and low-end performance must be recorded before calling this beta-ready. See [QA matrix](QA_MATRIX.md) and [known issues](BUGS.md).

## 18. Manual Firebase Console Steps Required

Current upload fingerprints and Play Integrity config were checked through API. Register the **Play app-signing** certificate if it differs. Configure a least-privilege Firebase Admin service account as a Supabase backend secret; never put its JSON in Git/Flutter. Verify crash and opt-in analytics delivery/retention in the Firebase Console. Do not enable Blaze for this free deployment.

## 19. Manual Google Play Console Steps Required

Use an existing developer account, or decide whether to pay Google's unavoidable registration fee. Complete identity verification, Data safety, Health apps/Health Connect declarations, content rating, app access, privacy/deletion URLs, store assets and closed-test setup. Upload the final signed AAB, add testers and verify Play-installed Auth/App Check. Console declarations and acceptance cannot be inferred from repository tests.

## 20. Exact Commands To Build Beta

See [release procedure](RELEASE.md) for all checks. With Flutter 3.29.3, JDK 17 and the existing private signing files, run from `frontend`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

## External actions still requiring access

Supabase CLI sign-in (`npx supabase login`) is required to deploy the Free Edge backend and retire the old proxy. Its account-deletion SQL and secret setup are detailed in [free-tier setup](FREE_TIER_SETUP.md). A Groq free server key is needed if one is not already configured. Never send tokens or passwords in chat. The deletion-request inbox must be operated by the owner.

## Device and artifact record

Connected phone: Nothing A069, Android 17, 1224×2720. Existing installation is release-signed with the matching key, version code 2002. An APK backup was saved privately before updating; no uninstall/data wipe was performed. Updated-build test evidence and final AAB checksum will be recorded after verification.
