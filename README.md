# Food Insight Scanner

Food Insight is a Flutter Android app for scanning packaged food, reviewing nutrition and ingredients, comparing products with a user's saved preferences, and logging meals. This repository is being prepared for a Google Play closed beta. It is **not yet verified on a release device or in Play closed testing**.

## What works in this branch

- Firebase email, Google and anonymous sign-in; UID-scoped user records.
- Barcode scanning with an authenticated backend that validates the barcode, fetches Open Food Facts, normalizes per-100g nutrition, and caches canonical facts in Firestore.
- Deterministic allergen and Personal Food Fit assessments. Missing facts remain unknown; package labels remain authoritative.
- Scan history, diet log, shopping list, profile, meal planning, AI chat, optional Health Connect activity, and Android widgets. Some user data is stored in Supabase with a UID-scoped SQLite outbox for offline operation.
- AI requests route through the shared `aiTask` backend handler, which validates requests/output, applies daily limits, and uses a server-side Groq secret. Alternatives, OCR, image chat and notifications are disabled.
- Firebase App Check, Crashlytics, rules tests, and an in-app account deletion path. Production operation depends on the deployment steps below.

## Architecture

Flutter and Provider render the app. Firebase Auth identifies users. Firebase App Check protects backend requests. `backend/` contains shared TypeScript handlers for product facts, AI and account deletion. Supabase Free Edge Functions is the default deployment; Firebase Functions remains an optional target requiring separate billing authorization. Firestore stores shared canonical products and legacy user records; Supabase holds current UID-scoped user records and private images. SQLite and preferences support local caching. See [architecture](docs/ARCHITECTURE.md), [data model](docs/DATA_MODEL.md), and [privacy map](docs/PRIVACY_DATA_MAP.md).

## Local development

Install Flutter stable, Android SDK, Node 22, Firebase CLI, and a JDK supported by the Firebase emulator (21+). Configure Firebase Android `google-services.json` and `frontend/lib/firebase_options.dart` for the same project. The checked-in Firebase client configuration is public; never put the Groq key or a Supabase service role key in the client. Supabase URL and anon key are public configuration, while RLS and Firebase JWT verification enforce access.

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
cd ../backend
npm ci
npm test
cd ../security-tests
npm ci
npm test
```

The test emulator uses the demo Firebase project and does not touch production. `flutter analyze` reports no issues. See [bugs](docs/BUGS.md) for current exceptions and [CI](.github/workflows/beta-ci.yml) for the automated gates.

## Deploy and release

Follow [Free-tier setup](docs/FREE_TIER_SETUP.md). Firebase remains on Spark; no billing account has been enabled. Deploy the shared backend to the existing Supabase Free project, apply deletion RLS, configure server secrets and retire the old proxy. Keep AI off until live checks pass. The [privacy](https://food-insight-scanner-app.web.app/privacy.html), [terms](https://food-insight-scanner-app.web.app/terms.html) and [deletion](https://food-insight-scanner-app.web.app/delete-account.html) pages are already hosted and are the app defaults.

Use [release procedure](docs/RELEASE.md), [App Check setup](docs/APP_CHECK_SETUP.md), [Play checklist](docs/PLAY_STORE_BETA_CHECKLIST.md), and [readiness report](docs/BETA_READINESS_REPORT.md). Do not invite testers until the listed live-service/device gates are closed.

## Product and data limitations

Open Food Facts is community maintained. A missing allergen tag, nutrient or ingredient list is not proof of safety. AI output is general information and may be wrong. Food Insight is not a medical device and does not provide treatment advice. Source attribution and data licensing must be reviewed before distributing a large derivative product database. See [product scope](docs/PRODUCT.md) and [security](docs/SECURITY.md).
