# FOOD INSIGHT FINAL BETA COMPLETION REPORT

Updated 4 October 2026. This is a verification record. The beta is **not yet fully accepted**: final device, release-artifact and current-head CI results must be recorded, and Play Console work remains.

## 1. Repository state

Repository: `aanandmodi/food-insight-scanner`, branch `main`. Author: `aanandmodi <aanandmodi09@gmail.com>`. Prior bot authors were corrected in an earlier coordinated history rewrite. New signing exposure has not been force-rewritten out of history. Current work targets version `1.0.2+2004`.

## 2. What was already complete

Owner-scoped local storage/outbox, Firestore rules and Supabase RLS, deterministic Food Fit/allergen checks, sodium normalization, editable meal estimates, deletion UI/guards, legal pages, camera lifecycle handling and ephemeral CI signing were retained.

## 3. Critical security fixes

Removed tracked signing material, added ignore patterns, a signing-secret guard and local pre-commit hook. Generated a replacement RSA upload key outside the repository; registered its public fingerprints with Firebase and removed the exposed certificate registrations. The owner confirmed no Play registration, so no upload-key reset was needed. Private backup location and public fingerprint are in SIGNING_INCIDENT.md. History still contains the compromised material; do not reuse it. Coordinate history removal separately.

## 4. CI status

Hosted run `36703883425` passed all four jobs on `a6d3b98`. That result predates this completion batch and is not evidence for the new head. New-head CI must pass before distribution. CI uses a throwaway certificate, never the upload key.

## 5. Backend architecture

Shared TypeScript implements scan, AI, alternatives and account deletion. Supabase Edge verifies Firebase identity, revocation and App Check, then invokes shared handlers. `food-insight-api` is deployed. The retired `ai-proxy` is deployed as HTTP 410. The deletion migration is applied. Firestore remains the canonical product cache and quota/flag store; Supabase stores private user records/images.

## 6. Free-tier architecture

Existing Firebase Spark, Supabase Free and Groq free account are retained. No billing upgrade or paid resource was enabled. Firebase has no legacy Storage bucket; cleanup explicitly uses `LEGACY_FIREBASE_STORAGE_ENABLED=false`. GitHub private-repository Actions uses included capacity. Exact service quotas can change; exhaustion must fail gracefully.

## 7. When payment would become necessary

Higher quotas or paid hosting would require a separate owner decision. No automatic upgrade is implemented. Google Play developer registration may require Google's fee if the owner has no existing account. App distribution through Play also requires account-holder declarations and testing gates.

## 8. AI models

| Route | Default | Tasks |
| --- | --- | --- |
| fast | `openai/gpt-oss-20b` | Meal parsing, product explanation, quick replies |
| smart | `openai/gpt-oss-120b` | Chat, plan, macro review |
| fallback | `openai/gpt-oss-20b` | One distinct retry on eligible transient errors |

All routes are server-configurable. Attempts time out after 22 seconds. Invalid output/auth errors and 429 are not retried. Provider cooldown is shared; quotas charge failed attempts too. Defaults: 200 global attempts/day and 10/minute, with per-user/task limits and smaller anonymous limits.

## 9. AI context architecture

Allowlisted device snapshots are rebuilt at the server boundary, capped at 14 KB. Missing intake stays unknown; logs are not treated as complete consumption. Sodium is mg, calories kcal, other nutrients g.

| Task | Context |
| --- | --- |
| Meal | Country, region and dietary preferences plus entered meal description |
| Product analysis | Product facts, deterministic Food Fit, profile, targets and today's known intake/remaining targets |
| Plan | Profile, targets, today's intake/remaining targets and up to eight recent meals |
| Chat | Above plus seven-day aggregates, up to five recent scans, approved aggregate activity and bounded conversation |
| Macro review | Adult profile, current deterministic targets, today, seven-day aggregates and activity summary |
| Quick replies | Latest assistant response, profile and today's target context |

Structured context excludes names, email, UID and raw Health Connect records. User-entered chat can contain personal information; bounded relevant conversation is sent to the provider as disclosed in the privacy policy.

## 10. AI Chat

At most 12 meaningful turns and 7,000 history characters. Local greetings and errors are excluded. Current product context is bounded. Responses are non-streaming; loading, retry and failure states preserve the conversation. A retry does not duplicate the failed user message. No persistent model-generated memory summary is added. Requests are timeout-bounded; true network cancellation is not implemented.

## 11. Product analysis

Food Fit remains deterministic. AI explains the supplied facts/result, with instructions not to invent nutrients, prices or safety claims. Live analysis returned validated JSON on 4 October. A successful fixture does not guarantee every generated statement is correct.

## 12. Meal parsing

Live Indian meal example passed. The prompt includes household portions and uncertain cooking oil. Results are estimates, reviewed and editable before saving. Manual entry remains available when AI fails.

## 13. Meal planner

Live four-meal generation passed. Validated unique meal types, ingredient lists and numeric ranges; totals are recomputed. Profile allergies/preferences, daily remaining targets and recent meals personalize the request. Existing deterministic client allergy validation remains before acceptance. No plan silently logs food.

## 14. Macro recalibration

Uses existing deterministic targets as the baseline. Known adult age and a baseline within the wellness ranges are required. Maximum adjustment is 10%, configurable downward. Calories 1500–4000, protein 30–300 g, carbs 100–600 g and fat 35–180 g are product guardrails, not medical recommendations. Fewer than three logged days retains the baseline. No weight trend is inferred. The scrollable dialog changes targets only after Apply Goals; Cancel changes nothing and duplicate submission is guarded.

## 15. Quick replies

AI generates two to four distinct short follow-up questions after meaningful responses. Output is validated and static suggestions remain as fallback. Live generation passed. No extra request is made for the greeting or an error.

## 16. Personal Food Fit

Allergen priority is preserved. Daily context adds explanations about known remaining protein, calories, carbs and fat with explicit per-100g comparison. Missing intake does not become zero. New daily explanations do not add arbitrary numeric penalties.

## 17. Verified alternatives

Uses real Open Food Facts records in the cached product's category, filtered for India. Server searches are capped at five/minute and 100/day with seven-day category caching. Client ranking requires sufficiently complete records, better known nutrition and compatible dietary/allergen data. No invented brands, images, prices or barcodes. Live scan succeeded; live alternatives returned an upstream 503, also reproduced directly against Open Food Facts. The UI offers retry; successful live retrieval remains outstanding.

## 18. India/INS intelligence

Bundled versioned glossary covers four verified identities: INS 211, 330, 322(i), 415. Codex/FSSAI source references are in the dataset and UI. Exact variant-aware parsing handles INS/E forms; unknown codes remain unknown. It works offline. This is a limited identity/function glossary, not exhaustive Indian regulatory approval, a toxicity score or clinical advice. Personalized additive-health rules are not fabricated.

## 19. Closed nutrition loop

Meal logs and profile targets feed the context builder for subsequent calls and daily Food Fit. Goal application updates the profile provider; existing log streams update the dashboard. Recent scans and bounded chat make subsequent questions relevant. Full physical-device navigation, sync and account-switch coverage remains to be recorded.

## 20. UI/UX improvements

Preserved green/warm-white identity. Added loading/retry/empty states for alternatives, source links for additives, contextual quick replies, a scrollable goal-review dialog and daily Food Fit explanations. Removed stale Gemini copy. Analytics stays opt-in and event-name-only; added feature-use events without food, chat or health parameters. Existing accessibility and estimate-review UI were retained. No redesign is claimed.

## 21. Tests added

Latest local Flutter suite: 44 passed; backend: 21 passed. New coverage includes context minimization/unknown values, Edge Buffer compatibility, routing/fallback/429, recalibration bounds and confirmation, additive variants and alternative filtering. Earlier local emulator suite: 13 passed; Edge suite: nine passed (rerun pending for latest adapter configuration). Flutter analyze passed before the final QA build configuration change; final CI will recheck it.

Live checks passed: missing/forged auth; missing/forged App Check; AI kill switch; six AI tasks; real barcode lookup; backend account deletion; stale-token rejection after deletion. Two-account RLS/private-storage tests passed on 1 October, including cross-user denial and fixture cleanup. QA debug attestation is not Play Integrity verification.

## 22. Manual steps required

Supabase login, deployment, secret configuration and key rotation are already done. Phone testing uses a separate QA package with the owner's approval to preserve existing data. The owner must handle Play identity/account declarations, closed-test participation and any account registration fee; register Play's app-signing fingerprint when issued. Operate the deletion-request inbox. Keep private signing backups secure. No credentials should be pasted in chat.

## 23. Remaining known risks

Pending: complete device matrix, final signed production artifact evidence, new-head CI, Play-installed Auth/App Check, successful upstream alternatives retrieval, low-end performance and Firebase telemetry delivery evidence. The four-entry additive glossary is intentionally limited. Some optional polish and true request cancellation remain. Historical exposed key material remains in Git history but is rotated. Do not call all 97 prompt sections complete while these gates remain.

## 24. Exact build commands

From `frontend`, Flutter 3.29.3 / Dart 3.7.2, JDK 17:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
flutter build apk --release --dart-define=QA_BUILD=true --obfuscate --split-debug-info=build/debug-info-qa
```

Only the first release command produces the production Play bundle. The QA package is separately labelled and uses debug App Check with a registered, revocable token. Never distribute QA as the production release.

## 25. Exact Supabase deployment commands

```powershell
npm test --prefix backend
npm run build:edge --prefix backend
npx supabase functions deploy food-insight-api --project-ref tslcgavpkujkfexzmisk --use-api
npx supabase functions deploy ai-proxy --project-ref tslcgavpkujkfexzmisk --use-api
```

The account-deletion migration was already applied; do not blindly replay existing migrations. Secret uploads use a private env file outside the repository.

## 26. Exact configuration/environment variables

Server secrets/config: `GROQ_API_KEY`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `AI_MODEL_FAST`, `AI_MODEL_SMART`, `AI_MODEL_FALLBACK`, `LEGACY_FIREBASE_STORAGE_ENABLED`; Supabase supplies `SUPABASE_SERVICE_ROLE_KEY`. Optional `QA_FIREBASE_APP_ID` permits only the separately registered QA app with valid App Check.

Firestore flags: `aiEnabled`, `aiChatEnabled`, `aiMealParserEnabled`, `aiMealPlannerEnabled`, `mealPlannerEnabled`, `aiProductAnalysisEnabled`, `aiRecalibrationEnabled`, `aiQuickRepliesEnabled`, `alternativesEnabled`, `additiveInsightsEnabled`. Limits: `aiGlobalDailyLimit`, `aiDailyLimits`, `macroMaxAdjustmentPercent`. AI flags were enabled after live verification. Flutter defaults to `BACKEND_TRANSPORT=supabase`; `QA_BUILD=true` is for separate QA builds only. No secret values are recorded here.
