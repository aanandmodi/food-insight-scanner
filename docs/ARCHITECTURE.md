# Architecture

## Runtime flow

```text
Flutter barcode camera → Firebase Auth + App Check → Supabase Edge → shared scanProduct handler
  → Firestore products/{barcode} cache (7 days) → Open Food Facts API
  → canonical per-100g product facts → local SQLite cache and product UI
  → deterministic AllergenSafetyService + FoodFitService
  → optional aiTask explanation via Groq
```

Flutter performs rendering, barcode detection, profile input, SQLite caching, and device integrations. Shared TypeScript backend handlers validate input, protect server secrets, normalize shared product facts, limit AI usage and coordinate account deletion. Firebase Auth is the account authority. App Check is enabled in Flutter and enforced on callables. Firestore rules deny client writes to canonical products and quotas. Current account records are primarily in Supabase with Firebase UID-scoped RLS and a local SQLite outbox; some legacy Firestore user paths remain for migration/compatibility. This split is deliberate until a verified migration exists.

## Ownership and lifecycle

`UserSession` captures a UID and generation before async work. `UserDataService` writes UID-scoped local records and syncs to Supabase using the same IDs. Supabase checks Firebase JWT claims in RLS. Sign-out clears widget values and invalidates pending work; local records stay scoped to their owner for later offline use. In-app deletion calls `requestAccountDeletion` after recent authentication. It cleans Supabase tables and images, Firestore paths, Firebase Storage, then Firebase Auth. An Auth deletion trigger retries cleanup if an account is deleted outside the app.

## Data trust boundaries

Open Food Facts is external community data. `productNormalizer.ts` converts sodium grams to milligrams and leaves missing nutrients null. `ProductFactsAdapter` handles old cache shapes cautiously; old ambiguous sodium is unknown. Allergen and Food Fit outcomes are deterministic and do not use LLM verdicts. AI input is length-bounded and delimited as untrusted data; output is validated server-side and again parsed in Flutter. AI does not write diet entries without a user confirmation.

## Operations

The app requires deployed Supabase migrations/RLS, Firebase rules and Supabase Edge backend, App Check providers, Groq secret, correct release signing, and legal Hosting pages. Feature flags live in Firestore `config/featureFlags`; the server checks `aiEnabled` and optional `aiChatEnabled`, `mealPlannerEnabled`, and `aiDailyLimits`. Disabled or unimplemented product features are hidden. See [security](SECURITY.md), [data model](DATA_MODEL.md), and [release](RELEASE.md).

## Free deployment transport

The default client calls `food-insight-api` with a refreshed Firebase bearer token and an App Check token. Its adapter checks revocation and the exact app ID, bounds streamed input, and invokes the same compiled handlers as Firebase Functions. There is no automatic insecure fallback. `BACKEND_TRANSPORT=firebase` is an explicit alternative only when a billing-backed Functions deployment is separately authorized. See [free setup](FREE_TIER_SETUP.md).
