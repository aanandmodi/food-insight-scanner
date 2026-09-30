# QA matrix

Updated 30 September 2026. `Automated` means a local test passed; it does not mean the corresponding production service is configured.

| Area | Evidence | Remaining live/device gate |
| --- | --- | --- |
| Auth routing/account switch | Automated loading, cached profile, retry and UID mismatch cases | Email/Google/guest end-to-end on updated phone |
| Owner isolation/offline outbox | SQLite tests and Firestore/Storage emulator tests | Supabase RLS retest after deletion migration |
| Scanner | Automated invalid manual barcode, actionable retry and large-text error | Camera denial, flashlight, repeated capture, known/unknown product, offline |
| Product | Sodium and allergen engine tests, full screen at text scale 1 and 2 | Live OFF lookup and existing-history compatibility |
| Diet log | Estimate-review, validation, save deduplication, local tombstone tests | Updated-device manual add/delete/cloud sync/offline |
| AI | JSON validation, global/UID quotas, race, kill switch, malformed provider, Edge auth tests | Deployed Groq success/429/timeout and App Check |
| Account deletion | Confirmation/cancel widgets; stale-token guards in rules | Disposable email/guest/Google cleanup, images, failure/retry |
| Health | Explicit consent and source separation; native rationale registered | Grant/deny/no data/disconnect on updated phone |
| Accessibility | Safety 1–2x text, full product at 2x, scanner 320px/2x | TalkBack and remaining full screens |
| Widgets | UID guards and clearing logic | Each size, owner switch, launcher refresh |
| Performance | Bounded requests, cache, release shrinking | Measured release launch/jank/memory and low-end device |
| Legal | Published pages HTTP 200; synced offline policy | Store declarations/inbox operations |
| Release | Same installed/upload certificate confirmed | Updated release APK and final AAB verification |

Physical-device results are recorded in the readiness report. Never mark blocked production AI/deletion as passed merely because the UI displays a graceful error.
