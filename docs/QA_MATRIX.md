# QA matrix

Updated 5 October 2026. `Automated` means a local test passed; it does not mean the corresponding production service is configured. Full acceptance remains subject to the unchecked scenarios below.

| Area | Evidence | Remaining live/device gate |
| --- | --- | --- |
| Auth routing/account switch | Automated loading, cached profile, retry and UID mismatch; phone email and guest entry, same-UID email upgrade with preserved profile/diet | Google sign-in and full account-switch matrix |
| Owner isolation/offline outbox | SQLite/rules tests; live owner/cross-user RLS and private storage; phone offline 300 kcal meal survives restart and syncs exactly once | Full account-switch/widget matrix |
| Scanner | Invalid/manual barcode tests; connected-phone preview and manual Nutella lookup; manual controls above floating nav | Camera denial, flashlight, repeated optical capture, unknown product, offline |
| Product | Sodium and allergen engine tests, full screen at text scale 1 and 2 | Live OFF barcode lookup passed; existing-history device compatibility pending |
| Diet log | Estimate-review, validation, save deduplication, local tombstone tests; phone estimate review/save and offline restart/sync | Full manual edit/delete and conflict matrix |
| AI | 23 backend tests and nine Edge tests; six live tasks, auth/App Check rejection; structured-history BMI returns 22.7; real alternatives retrieval; phone chat, meal estimate, planner and insufficient-data recalibration review | Apply-goal confirmation, failures/retries and Play attestation |
| Account deletion | Confirmation/cancel widgets; phone email deletion and upgraded guest deletion with reauthentication; Firebase UID and all seven private tables cleared | Google cleanup, image deletion, failure/retry |
| Health | Two service tests; native interval null-pointer reproduced and fixed; phone Settings connection/import/disconnect/reconnect passed | Fresh permission grant/deny, revocation timing, unavailable provider and pedometer fallback |
| Accessibility | 57 Flutter tests include 1–2x dietary-card/summary/guest-auth layouts and long chat; phone cards show no overflow | TalkBack and remaining full screens |
| Widgets | UID guards and clearing logic | Each size, owner switch, launcher refresh |
| Performance | Release phone chat p95 raster 2.1–3.6 ms; Goals & Diet 4.3–7.7 ms; bounded requests/cache/shrinking | Full startup/memory benchmarks and low-end device |
| Legal | Published pages HTTP 200; synced offline policy | Store declarations/inbox operations |
| Release | Final 1.0.2+2004 QA installed; production AAB signature/package/version/hash verified against replacement upload key; original installation preserved | Play account/declarations, internal-test install, Play signing/Auth/App Check |

Physical-device results are recorded in the readiness report. Never mark blocked production AI/deletion as passed merely because the UI displays a graceful error.

## Current device findings

Nothing A069, Android 17. The separate `com.food_insight_scanner.app.qa` release preserves the original package/data. Email login/profile load, camera preview, manual product lookup, long chat, recalibration review and Health Connect Settings import were exercised. Nutrient/source explanations are in info sheets; connection actions are absent from the activity tile. Home cards continue behind the floating bar. Goals & Diet descriptions fit without overflow. QA debug attestation does not verify Play Integrity.

Hosted source `0c8b656`: Flutter, backend, rules and Android compilation all passed in run `37195264934`. Current continuation results are recorded in the readiness report and delivery message.

Release chat measurements exposed slow Impeller raster frames on this device. In a renderer comparison, Skia warm batches had p95 raster times about 2–3 ms, below the 8.33 ms budget at 120 Hz; the preceding Impeller run had 24–33 ms. Android uses the supported Skia compatibility setting for Flutter 3.29. Recheck on SDK upgrades and other devices; this is not evidence for every phone.
