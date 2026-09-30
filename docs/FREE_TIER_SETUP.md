# Free-tier deployment

The owner's constraint is free services/free tiers. On 30 September 2026 the Firebase project's billing API returned `billingEnabled: false`. Do not upgrade it to Blaze. Firebase Functions requires a billing account; Firebase Storage also requires Blaze. The code retains those handlers, but the default mobile transport is Supabase Edge Functions so no technology or data migration is needed.

## Services

| Service | Choice | Limit/operation |
| --- | --- | --- |
| Firebase Auth | Existing Spark project; email, Google, anonymous | No SMS authentication |
| Firestore | Spark; existing product cache and flags | Spark daily quotas; excess availability is not guaranteed |
| App Check, Crashlytics, Analytics | Firebase no-cost products | Analytics is opt-in; no advertising |
| Firebase Hosting | Spark | Legal pages only, no custom domain needed |
| Supabase | Existing Free project `tslcgavpkujkfexzmisk` | Free Edge invocation/storage/egress limits; projects may pause when inactive |
| Groq | Free account/key only | Quotas stop excess requests; do not enable paid service |
| GitHub Actions | Standard Ubuntu runners | This repository is private: stay within included Actions minutes; do not buy larger runners or enable paid overages |
| Google Play | Existing developer account, if available | A new Play account has a registration fee; this cannot be supplied by a free hosting tier |

The app fails gracefully at backend/provider limits. A billing budget alert is **not** a hard spending cap. We have not enabled billing or purchased a service.

Sources: [Firebase pricing](https://firebase.google.com/pricing), [Firebase Storage requirements](https://firebase.google.com/docs/storage/faq-and-troubleshooting), [Supabase Edge pricing](https://supabase.com/docs/guides/functions/pricing), [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

## Shared backend deployment

`backend/src/` remains the source of truth. `npm run build:edge` bundles its three callables into `supabase/functions/food-insight-api/backend.js`. CI rejects bundle drift. The Edge adapter verifies revoked/disabled Firebase users and App Check tokens for the exact Android app before calling shared handlers. It does not accept client-provided identity or system prompts. Firestore continues to hold the canonical product cache, flags and atomic quotas.

1. Run `npx supabase login` locally. Never paste access tokens in chat or commit them.
2. Verify that the target project is on Supabase Free. Apply the account-deletion migration `supabase/migrations/202609290001_account_deletion.sql` after the earlier migrations. Do not blindly reapply the earlier policies if they are already present.
3. Configure a dedicated Google service account for this backend, with Firestore data access and Firebase Auth user administration only. Legacy Firebase Storage cleanup additionally needs object-list/delete access on the existing bucket, if one exists. Do not grant Project Owner/Editor. Store its JSON **only** as Supabase secret `FIREBASE_SERVICE_ACCOUNT_JSON`. A missing/inaccessible legacy bucket must be investigated, not silently ignored unless it is genuinely absent (404).
4. Set `GROQ_API_KEY` as a Supabase secret from a Groq free account. Supabase provides `SUPABASE_SERVICE_ROLE_KEY` automatically to Edge Functions. These values never go into Flutter or Git.
5. From `backend`, run `npm ci`, `npm test`, `npm run build:edge`. From the root run `npx supabase functions deploy food-insight-api --project-ref tslcgavpkujkfexzmisk` and `npx supabase functions deploy ai-proxy --project-ref tslcgavpkujkfexzmisk`. The old proxy now returns HTTP 410 and must be retired remotely too.
6. Keep Firestore `config/featureFlags.aiEnabled` false until scan, AI, quota and deletion are verified on a disposable account. Then enable desired AI features. `aiGlobalDailyLimit` can lower the global 200/day cap; per-task `aiDailyLimits` can also be lowered.

No Firebase Auth deletion trigger is deployed on Spark. External deletion requests must use the same backend cleanup operation before deleting Auth; deleting a user directly in the Firebase Console alone is insufficient. The optional Functions implementation retains a retrying Auth trigger for operators who separately authorize a billed Firebase deployment.

## Already published

- [Privacy](https://food-insight-scanner-app.web.app/privacy.html)
- [Terms](https://food-insight-scanner-app.web.app/terms.html)
- [Account deletion](https://food-insight-scanner-app.web.app/delete-account.html)

These return HTTP 200. The app defaults to these URLs. Android's Health Connect rationale screen uses an identical bundled policy; run `python tools/sync_legal_assets.py` after editing legal pages.
