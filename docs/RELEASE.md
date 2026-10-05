# Release procedure

Android ID: `com.food_insight_scanner.app`; version `1.0.2+2004`. The upload certificate was rotated after exposure. An existing installation signed with the old certificate cannot receive this APK in place. Physical testing uses the separate `com.food_insight_scanner.app.qa` package to preserve the original installation and its data. The default backend is Supabase Free Edge with shared TypeScript handlers; Firebase remains on Spark.

## Deployment

Follow [free-tier setup](FREE_TIER_SETUP.md). Do not run a blanket `firebase deploy` that attempts paid Functions/Storage provisioning. The safe deployed targets are Hosting and Firestore rules:

```powershell
firebase deploy --only 'hosting,firestore:rules' --project food-insight-scanner-app
```

Legal URLs are built-in defaults and have been verified publicly. App Check Play Integrity configuration and the local release SHA-1/SHA-256 are registered. Play App Signing may use a different certificate; register that certificate when Play provides it.

## Checks and builds

Use Flutter 3.29.3, JDK 17 for Android, Node 22 for backend, JDK 21+ for Firebase emulators. Do not commit a machine-specific Java path in Gradle properties. On this Windows host Flutter is configured to the installed JDK 17.

```powershell
python tools/sync_legal_assets.py --check
cd backend
npm ci
npm test
npm run build:edge
cd ../supabase/functions/food-insight-api
npx deno check index.ts
npx deno test --allow-env --allow-read --allow-sys handler_test.ts runtime_test.ts
cd ../../../frontend
flutter pub get
flutter analyze
flutter test
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
cd ..
python tools/check_android_alignment.py frontend/build/app/outputs/bundle/release/app-release.aab
cd frontend
cd ../security-tests
npm ci
npm test
```

Release signing requires the ignored `frontend/android/key.properties`, pointing to the replacement key outside Git as documented in [signing incident](../SIGNING_INCIDENT.md). Preserve that replacement identity and its private backup. APK/AAB outputs and matching symbols remain private. CI creates a short-lived test certificate only to verify release compilation/shrinking; its AAB must never be distributed.

## Release decision

Record final artifact checksum, signing fingerprint, device results and cloud deployment in [readiness report](BETA_READINESS_REPORT.md). Complete [QA matrix](QA_MATRIX.md) and [Play checklist](PLAY_STORE_BETA_CHECKLIST.md). A build is not proof of functional cloud deployment. Supabase backend deployment and disposable-account deletion must pass before calling the build beta-ready.
