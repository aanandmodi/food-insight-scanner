# Food Insight Scanner — Forward Plan

> **Status of this document:** written August 2026, immediately after the market-readiness pass
> (release signing, code obfuscation, multi-ABI builds, AI-migration cleanup).
> It supersedes and absorbs `future_roadmap_and_security.md`, which is now partly stale — that
> document still warns about a hardcoded **Gemini** key, but the app moved to **Groq** and the key
> now resolves through `Env` / `SharedPreferences` (see `lib/core/config/env.dart`).

---

## 1. Honest baseline — what actually exists today

Before planning forward, this is the real state, so nothing below is built on a false premise.

| Capability | State | Where it lives |
| :--- | :--- | :--- |
| Barcode scan → product lookup | Working | `lib/presentation/barcode_scanner/`, `lib/services/product_service.dart` |
| Open Food Facts integration + 7-day cache | Working | `lib/services/cloud_function_service.dart` |
| AI: product analysis, meal parsing, diet plans, chat, alternatives, quick replies | Working, **direct HTTP to Groq** | `lib/services/cloud_function_service.dart` |
| Auth: Google, Email/Password, Guest | Working | `lib/services/auth_service.dart`, `lib/core/auth_gate.dart` |
| Per-user cloud data scoped to `uid` | Working | `lib/services/firestore_service.dart` |
| Offline-first local cache | Working | `lib/services/local_database_service.dart` (SQLite) |
| Image/avatar storage | Working | `lib/services/supabase_storage_service.dart` |
| Health Connect steps + active calories | Working | `lib/data/services/activity_service.dart` |
| Android home-screen widgets (3 sizes) | Working | native Kotlin providers |
| Design system, glassmorphism, animations | Working | `lib/theme/`, `lib/widgets/skeuomorphic/` |
| **Release signing + obfuscation** | **Done in this pass** | `android/app/build.gradle`, `key.properties` |
| Automated tests | **None** | — |
| Push notifications | **None** | — |
| Backend AI proxy (key off-device) | **Not deployed** | `backend/src/` exists but unused |
| Paid tier / monetization | **None** | — |

**The single biggest architectural liability:** the Groq key currently ships inside the APK (or is
pasted by the user). Section 2.1 is therefore the highest-priority item in this whole document.

---

## 2. Phase A — Hardening required before a *public* launch

These are not features. These are the things that make a public release safe and supportable.

### 2.1 Move the AI key off the device (BFF proxy) — **P0**

Anything compiled into an APK is recoverable with `apktool` in minutes. A shipped Groq key means
a stranger can spend your quota.

The scaffolding already exists in `backend/src/` (7 TypeScript functions, currently bypassed).
The plan:

1. Deploy a single `aiProxy` endpoint — Cloud Run, Cloudflare Workers, Fly.io, or Vercel. Cloud
   Functions was abandoned to dodge the Firebase Blaze requirement; Cloudflare Workers has a free
   tier with no card required and is the cheapest path back to a server-side key.
2. The endpoint verifies a **Firebase ID token**, rate-limits per `uid`, injects the Groq key, and
   forwards to Groq.
3. Ship the app with `--dart-define=AI_PROXY_URL=https://…`. No code change is needed — the client
   already branches on `Env.useAiProxy` and routes through the proxy when it is set.
4. Add **Firebase App Check** so only genuine, unmodified installs can call the proxy.

**Why this is cheap:** the client-side work is already done. This is purely a deploy + one build flag.

### 2.2 Register release SHA fingerprints — **P0**

Google Sign-In silently fails on release builds whose signing certificate isn't registered.
The release keystore generated in this pass has:

```
SHA-1:   4F:A5:38:E6:49:C6:5C:5C:00:D9:99:30:97:E2:89:9A:2B:11:32:AC
SHA-256: 03:77:C1:38:C4:6A:0D:F6:A0:43:C4:CD:2E:19:59:E5:87:7C:3F:6E:52:F4:1D:82:C7:09:1F:B2:63:09:2D:FB
```

Add both in Firebase Console → Project Settings → Android app, then re-download
`google-services.json`. If you later use Play App Signing, register Google's re-signed
fingerprint too.

### 2.3 Account deletion & data export — **P0 for store compliance**

Google Play requires an in-app path to delete an account and its server-side data. Needed:

- `deleteAccount()` in `auth_service.dart` — cascade-delete the Firestore `users/{uid}` subtree,
  Supabase avatar objects, and local SQLite rows.
- "Export my data" producing a JSON dump (GDPR/DPDP portability).
- A public privacy policy URL — mandatory for a Play listing, doubly so for health data.

### 2.4 Crash & error observability — **P0**

Right now a crash on a user's device is invisible. Add **Firebase Crashlytics** plus a
`FlutterError.onError` hook, and record handled `AiRequestException`s as non-fatals so AI
reliability becomes measurable rather than anecdotal.

### 2.5 Test coverage — **P1**

Zero tests today. Highest-value first:

- **Unit:** `UserUtils.calculateTDEE()` (drives every macro goal — a silent error here corrupts the
  entire product), `_extractJson()` against a corpus of malformed LLM output, date-key helpers.
- **Widget:** `AuthGate` state machine, diet-log add/remove, scanner permission-denied path.
- **Integration:** scan → analyse → log, on a real device.
- Wire into GitHub Actions: `flutter analyze --fatal-infos` + `flutter test` on every PR.

### 2.6 Pay down known debt — **P2**

- `flutter_markdown` is discontinued → migrate to `flutter_markdown_plus`.
- `supabase_flutter`'s `anonKey` is deprecated → `publishableKey`.
- ~99 analyzer infos remain; the `use_build_context_synchronously` ones are genuine latent crashes
  and deserve a dedicated sweep.
- Add a **universal APK vs. per-ABI** decision to the release checklist (per-ABI is ~40% smaller).

---

## 3. Phase B — New screens

Concrete additions, each with a reason to exist. Ordered by value-per-unit-effort.

### 3.1 Insights / Trends dashboard ★ highest value
The app records a lot and reflects back little. `fl_chart` is already a dependency.

- Weight trajectory vs. goal, with a projected date-to-goal.
- 7/30/90-day calorie and macro adherence bands.
- "Your top 10 most-scanned products, ranked by safety score."
- Streaks (consecutive logging days) — the single most effective retention mechanic in this category.
- Weekly AI digest: *"You averaged 18g fibre against a 30g target; here are three fixes."*

### 3.2 Recipe detail + cooking mode
Diet plans currently produce meal *names*. Users then have to go elsewhere to cook them — a
retention leak straight out of the app.

- Ingredients scaled to servings, step-by-step method, per-serving macros.
- Screen-awake step-through cooking mode with timers.
- One-tap "add missing ingredients to Shopping List" (the list already exists).

### 3.3 Meal photo logging
Camera plumbing is already present for scanning. Point it at a plate instead of a barcode and send
the image to a vision model to estimate contents and portions. This is the single most-requested
feature in every competing nutrition app, and it removes the biggest friction point: barcode-less
food (home cooking, restaurants, produce).

### 3.4 Barcode-not-found contribution flow
Open Food Facts has real coverage gaps, especially for regional Indian products. Today a miss is a
dead end. Instead: let the user photograph the label, OCR it, and submit back to OFF. Every
contribution improves the shared database and makes the app the obvious tool for under-covered
markets.

### 3.5 Product comparison
Scan two or more items and diff them side by side — macros, additives, safety score, price per
100g. This is the natural in-aisle decision moment and is currently unserved.

### 3.6 Fasting / meal-timing tracker
Eating *window* matters as much as content for a large slice of the target audience. A simple
16:8 timer with a ring that matches the existing design language is low effort and high stickiness.

### 3.7 Onboarding tutorial carousel
First-run currently drops users straight into profile setup with no explanation of what the app
does. A 3-slide "scan → understand → log" walkthrough measurably lifts activation.

### 3.8 Paywall / subscription screen
Required once Section 6 lands.

---

## 4. Phase C — Features on existing screens

- **Continuous batch scanning** — keep the camera live and queue an entire trolley, rather than
  one-scan-one-navigation.
- **OCR ingredient reader** — for unpackaged or barcode-less food; `google_mlkit_text_recognition`
  runs fully on-device and free.
- **Voice meal logging** — `speech_to_text` into the existing `parseMeal()`. Talking is far faster
  than typing, especially mid-meal.
- **Barcode → "can I eat this?" instant verdict** — a single full-screen green/amber/red answer
  against the user's allergen profile, before any detail. Most scans are that one question.
- **Water intake tracking** — trivially simple, universally expected, drives daily opens.
- **Custom & saved foods** — user-defined items and "favourite meals" for one-tap re-logging of
  the same breakfast every day.
- **Recurring/copy meals** — "same as yesterday" duplication.
- **Home widget deep-links** — the widgets render data but tapping them could log water or open
  the scanner directly.
- **Smart notifications** — meal-time log reminders, streak-risk nudges, weekly digest. Needs FCM
  (see 5.1). Must be genuinely useful or they get muted, which is worse than not sending them.
- **Localisation (i18n)** — Hindi first, given the regional-product focus. Also unlocks a much
  larger addressable market than an English-only listing.
- **Full accessibility pass** — semantic labels, dynamic type, contrast audit. A heavily
  glassmorphic, low-contrast design needs this checked deliberately rather than assumed.

---

## 5. Phase D — Integrations

### 5.1 Firebase Cloud Messaging — *foundational*
Gate for every notification feature above.

### 5.2 Deeper health-platform sync
`health` is already wired for steps and active calories. Extend to **write** consumed nutrition
back into Apple Health / Health Connect so Food Insight becomes a good citizen of the user's
existing health graph rather than a silo. Add sleep and weight reads to feed the AI.

### 5.3 Wearables — direct OAuth
Fitbit, Garmin, Oura for HRV, sleep stages, and recovery. Feed into dynamic macro adjustment (7.2).
Worth doing only *after* the health-platform path is solid, since Health Connect already proxies
much of this.

### 5.4 Continuous glucose monitors
Dexcom / Libre. The genuinely differentiating integration: correlate a scanned food with the
user's own post-meal glucose response and rank alternatives by *their* measured reaction rather
than a generic score. Niche today, but this is where nutrition tech is heading, and the scan-first
architecture is unusually well suited to it.

### 5.5 Grocery / commerce
Deep-link the shopping list into BigBasket, Blinkit, Zepto, Instacart. Natural affiliate revenue
and a real convenience win — the list already exists and is currently a dead end.

### 5.6 Restaurant & chain menu data
Nutritionix or FatSecret for eating out, the largest current blind spot in logging.

### 5.7 Apple platform parity
An `ios/` directory exists but is unexercised. Needs HealthKit entitlements, Sign in with Apple
(mandatory if Google Sign-In is offered), and iOS widgets.

---

## 6. Monetization

A freemium split that keeps the core genuinely useful — a crippled free tier would undercut the
contribution and habit loops that make the product work:

| Tier | Contents |
| :--- | :--- |
| **Free** | Unlimited barcode scanning, safety/allergen verdicts, manual logging, scan history, shopping list |
| **Premium** | AI chat, AI diet plans, meal photo recognition, Insights/Trends, wearable + CGM sync, data export, weekly digest |

- Implement with **RevenueCat** — one integration covers both stores and handles receipt
  validation, which is easy to get subtly wrong by hand.
- Premium subscribers are also the natural bearers of AI inference cost, which makes 2.1's proxy
  rate-limits straightforward to tier.
- Secondary revenue: grocery affiliate links (5.5). Avoid ads — they read as untrustworthy in a
  health context.

---

## 7. AI roadmap

The AI layer is currently *reactive* — it answers when asked. The opportunity is making it *proactive*.

1. **Micronutrient depth** — go beyond macros to iron, B12, vitamin D, calcium, and flag chronic
   deficiency patterns across weeks. This is where scanned-ingredient data genuinely outperforms
   manual calorie counters.
2. **Dynamic macro adjustment** — recompute goals daily from actual activity (already ingested via
   Health Connect) and recent adherence, instead of a static TDEE.
3. **Predictive nudges** — learn the user's craving windows from their own log timestamps and
   intervene before the lapse rather than recording it afterwards.
4. **Personal food graph** — a per-user embedding of accepted/rejected foods so alternatives get
   sharper over time. This is the compounding moat: it cannot be copied, because it is *their* data.
5. **Cheaper inference tiering** — route trivial calls (quick replies, simple parses) to
   `llama-3.1-8b-instant` and reserve `llama-3.3-70b-versatile` for real analysis. Meaningful cost
   reduction once the proxy is metering usage.
6. **On-device fallback** — Gemma via `flutter_gemma` for basic parsing offline, so the app degrades
   gracefully rather than failing when there is no signal.

---

## 8. Suggested sequencing

Ordered so that each phase unblocks the next, rather than by raw appeal.

| Phase | Focus | Rough effort |
| :--- | :--- | :--- |
| **A0** | AI proxy + App Check, SHA registration, account deletion, Crashlytics, privacy policy | 1–2 weeks |
| **A1** | Test suite + CI, dependency debt, `BuildContext` sweep | 1–2 weeks |
| **B0** | Insights/Trends, water tracking, saved foods, streaks | 2–3 weeks |
| **B1** | Meal photo logging, instant "can I eat this?" verdict | 2–3 weeks |
| **C0** | FCM + smart notifications, home-widget deep-links | 1–2 weeks |
| **C1** | Recipe detail + cooking mode, product comparison | 2–3 weeks |
| **D0** | RevenueCat + paywall, premium gating | 1–2 weeks |
| **D1** | Hindi localisation, accessibility pass, iOS parity | 3–4 weeks |
| **E** | CGM / wearable OAuth, grocery commerce, personal food graph | ongoing |

**If only one thing gets done:** deploy the AI proxy (2.1). It is the only item that is both a
security necessity and a prerequisite for metering, tiering, and monetization.

---

## 9. Anti-goals

Worth stating explicitly, to keep scope honest:

- **No social feed.** Food logging is private; social layers in this category consistently fail.
- **No medical claims.** "Diabetes management" as a *goal preset* is fine; diagnosis or dosing is
  not, and it would drag the app into regulated territory.
- **No ads.**
- **Don't build custom per-brand wearable integrations** before Health Connect / HealthKit is
  fully exploited — it proxies most of them for a fraction of the work.
</content>
