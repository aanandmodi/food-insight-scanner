# QA matrix

Updated 4 October 2026. `Automated` means a local test passed; it does not mean the corresponding production service is configured.

| Area | Evidence | Remaining live/device gate |
| --- | --- | --- |
| Auth routing/account switch | Automated loading, cached profile, retry and UID mismatch cases | Email/Google/guest end-to-end on updated phone |
| Owner isolation/offline outbox | SQLite tests and Firestore/Storage emulator tests | Passed live owner/cross-user RLS and private storage on 1 October; device offline/account switching pending |
| Scanner | Automated invalid manual barcode, actionable retry and large-text error | Camera denial, flashlight, repeated capture, known/unknown product, offline |
| Product | Sodium and allergen engine tests, full screen at text scale 1 and 2 | Live OFF barcode lookup passed; existing-history device compatibility pending |
| Diet log | Estimate-review, validation, save deduplication, local tombstone tests | Updated-device manual add/delete/cloud sync/offline |
| AI | JSON validation, global/UID quotas, race, kill switch, malformed provider, Edge auth tests | Six live AI tasks and negative auth/App Check passed; 429/timeouts covered by automated tests; device flow pending |
| Account deletion | Confirmation/cancel widgets; stale-token guards in rules | Disposable email/guest/Google cleanup, images, failure/retry |
| Health | Explicit consent and source separation; native rationale registered | Grant/deny/no data/disconnect on updated phone |
| Accessibility | Safety 1–2x text, full product at 2x, scanner 320px/2x | TalkBack and remaining full screens |
| Widgets | UID guards and clearing logic | Each size, owner switch, launcher refresh |
| Performance | Bounded requests, cache, release shrinking | Measured release launch/jank/memory and low-end device |
| Legal | Published pages HTTP 200; synced offline policy | Store declarations/inbox operations |
| Release | Replacement upload key generated; separate QA package preserves old installation | QA release APK built and installed; production AAB verification pending |

Physical-device results are recorded in the readiness report. Never mark blocked production AI/deletion as passed merely because the UI displays a graceful error.

## Current device findings

Nothing A069, Android 17. A separate `com.food_insight_scanner.app.qa` release installs successfully without altering the original package. Email login and profile loading succeeded. Camera permission and scanner preview opened. The tab bar overlapped the manual barcode control; the fix reserves a bottom navigation area and wires scanner close to Home. Retest is in progress. QA debug attestation is explicitly registered and revocable; it does not verify Play Integrity.

Current-hosted source `8fbe659`: Flutter, backend, rules and Android compilation all passed in run `37179985064`. The navigation fix is newer and needs its own verification.
