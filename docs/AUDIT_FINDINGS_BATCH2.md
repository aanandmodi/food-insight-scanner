# Audit batch 2 — 14 confirmed bugs (auth / AI / providers)

Adversarially verified. Ordered by severity. **All 14 fixed** — analyzer clean
(99 info-only issues, unchanged count, zero errors/warnings).

## Shared root cause (bugs 2, 3, 13)
`FirestoreService.getUserProfile()` caught its own Firestore timeout/network
errors and returned `null`, identical to "no document exists". Every caller then
treated a transient read failure as "brand-new user" and either overwrote the
real cloud profile or forced re-onboarding.

**Fixed at the source, additively:** new `ProfileLoadResult` (found / absent /
failed) + `FirestoreService.loadUserProfile()`. `getUserProfile()` is retained as
a thin wrapper with byte-identical behaviour, so no existing caller changed
semantics. The three callers above now branch on `failed`.

- [x] **1 [HIGH]** `main.dart` — Flutter's `defaultGenerateInitialRoutes` splits `/splash-screen` into `['/', '/splash-screen']` and builds both; `/` maps to AuthGate, so every cold start mounted a competing gate underneath the splash (two `authStateChanges` listeners, an off-screen HomeDashboard/ProfileSetup duplicating their startup loads, back button popping to a phantom route). Added `onGenerateInitialRoutes` building only the requested route. Auth decision logic untouched.
- [x] **2 [HIGH]** `auth_service.dart` `_ensureProfileDocument` — now writes the default document only when the read *positively confirmed* absence (`existing.exists || existing.failed` → return). A timeout used to land in the merge-write and stamp `name:''`/`profileCompleted:false` over a complete cloud profile. Still fully wrapped in try/catch; cannot throw into the auth flow.
- [x] **3 [HIGH]** `splash_screen.dart` — a failed profile read no longer counts as "onboarding incomplete". Shows the existing `_hasError` retry state instead of routing to ProfileSetup (which then overwrote the real profile).
- [x] **4 [HIGH]** `settings_screen.dart` — `CloudFunctionService().invalidateKeyCache()` now called after saving/removing the key, so the memoized `_memoKey` no longer keeps sending the old key until an app restart.
- [x] **5 [HIGH]** `cloud_function_service.dart` — `timeout` now bounds the **whole** call rather than each attempt (stopwatch + budget-clamped backoff), and the scan-path analysis call is capped at 10 s. Three 45 s attempts plus backoff ran ~136 s, tripping `getProductByBarcode`'s 25 s budget and discarding a product that had already been fetched successfully → user saw "not found".
- [x] **6 [MED]** `auth_service.dart` `signUpWithEmail` — `updateDisplayName`/`reload` wrapped; the account already exists at that point, so a transient failure no longer reports the whole signup as failed (which stranded users with an account they couldn't recreate: "email already in use").
- [x] **7 [MED]** `auth_service.dart` — `saved_meal_plan`/`saved_meal_plan_at` added to the signOut scrub list; the next account no longer opens Meal Planner to the previous user's AI plan.
- [x] **8 [MED]** `ai_chat_assistant.dart` — passes structured `history:` turns instead of the deprecated `conversationHistory` string, which split every reply on newlines (shredding multiline assistant turns into bogus turns) and made the 20-turn window cap count lines instead of messages.
- [x] **9 [MED]** `ai_chat_assistant.dart` — error banner now type-checks `AiUnavailableException` / `AiRequestException.isAuthFailure` / `.isRateLimited`. The old `contains('429')`/`contains('api key')` tests could never match, because these exceptions stringify to a human sentence with no status code — so a rejected key or a rate limit both told the user to check their internet.
- [x] **10 [MED]** `cloud_function_service.dart` — `_num` accepts thousands separators (`'1,800'` → 1800, was 1). The old regex stopped at the comma, collapsing large AI values to a single digit and tripping the plausibility guard.
- [x] **11 [MED]** `user_utils.dart` — **worse than first reported: 4 sites, not 2.** The dropdown persists `weight_loss`, and `'weight_loss'.contains('lose')` is false *and* `contains('weight loss')` is false (underscore ≠ space), so the main `calculateTDEE` path skipped the −500 deficit and `calculateProteinGoal` used 0.8 g/kg alongside both fallbacks. Replaced with shared `_normalizeGoal`/`_isWeightLoss`/`_isMuscleGain` helpers that flatten separators and match the `loss` stem. Activity levels were checked too and are fine (stored values match the multiplier keys exactly).
- [x] **12 [MED]** `activity_provider.dart` — added a `_baselineDate` guard that rebaselines at the date boundary. The Health-Connect branch captured `_initialBaseSteps` once at app open, so staying open past midnight kept adding today's delta to yesterday's total and the new day opened with the ring already full.
- [x] **13 [MED]** `user_profile_provider.dart` — a failed read now sets `_errorMessage` (so the existing `hasError` retry branch in AuthGate actually fires) and keeps any in-memory profile, instead of reporting `null` and routing an existing user into onboarding.
- [x] **14 [LOW]** `home_dashboard.dart` — `_loadUserData` now passes the same `customGoal` overrides as `_buildHomeContent`, so the home-screen widget (fed from there) no longer shows the formula goal while the app shows the AI-adjusted / manually-set goal.

## Noted, deliberately not changed
- `groq_api_key` is **not** scrubbed on sign-out. It's a device-level setting the
  user pays for; clearing it would force re-entry after every sign-out. Worth
  revisiting if multi-user device sharing becomes a target scenario.
- `pedometer_today_date` / `pedometer_today_start_steps` are **not** scrubbed on
  sign-out either — they describe the hardware step counter, not account data,
  and clearing them would make the same user lose today's steps after a
  sign-out/sign-in round trip.
