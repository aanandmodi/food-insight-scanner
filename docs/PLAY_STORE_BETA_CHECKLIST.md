# Google Play closed beta checklist

Record owner, date, device and evidence for every item. A locally built AAB alone does not close this checklist.

## Repository and services

- [ ] Flutter analyze/test, backend test/build and Firebase emulator rules tests pass in CI on the release commit.
- [ ] Deploy Supabase migrations in order and test RLS with two Firebase UIDs and both image buckets.
- [ ] Set Firebase Functions `GROQ_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY`; deploy Functions, Firestore rules/indexes and Storage rules to the intended project.
- [ ] Create `config/featureFlags` with documented limits and confirm `aiEnabled` kill switch works. Verify quota counters cannot be changed by a client.
- [ ] Retire the deployed Supabase AI proxy and remove unused deployed legacy Firebase AI endpoints after old clients are accounted for.
- [ ] Register App Check Play Integrity and debug providers; verify enforcement in release.
- [ ] Verify email, guest and Google authentication and account upgrade. Register both upload and Play app-signing SHA fingerprints in Firebase.
- [ ] Test in-app account deletion end to end for email, Google and guest, including Supabase rows/images, Firestore and local caches. Operate the external deletion inbox.

## Product QA on physical devices

- [ ] Fresh install, app upgrade, logout/account switch, offline restart and low storage.
- [ ] Scan valid/invalid/unknown barcode; deny camera; use flash/manual entry; repeat scan; test slow and offline lookup.
- [ ] Review complete and incomplete products, missing image/ingredients/allergens, high sodium/sugar, allergen conflict, trace conflict, vegan conflict and unknown Food Fit.
- [ ] Log and delete a portion; verify daily totals, offline queue/cloud sync and widget updates without previous-user values.
- [ ] AI success, timeout, disabled switch, quota, malformed response, backend outage and meal confirmation/undo.
- [ ] Health Connect available/unavailable, permission granted/denied/revoked, zero data, phone counter estimate and no silent permission request.
- [ ] Small/large screen, 200% text, TalkBack, keyboard navigation, contrast and status/navigation bars; run on a 4 GB Android device.
- [ ] Crashlytics opt-in/out and one controlled non-sensitive test crash in a non-production test account; inspect Console delivery.

## Play Console

- [ ] Increment version code. Upload the correctly signed release AAB to a **closed test** track; verify package and Play signing certificate.
- [ ] Complete app access instructions for review, content rating, target audience, ads declaration, Data safety, account deletion link, Health apps declaration, Health Connect permission rationale and privacy policy link.
- [ ] Deploy and open `privacy.html`, `terms.html`, `delete-account.html` without login from an incognito browser; set the same public URLs in the AAB dart-defines and Play listing.
- [ ] Prepare honest screenshots and listing copy; avoid medical efficacy or allergen safety claims. Add Open Food Facts attribution and license review.
- [ ] Install from Play closed test, verify sign-in, App Check, scanning, AI, deletion, crash reporting, Health Connect, widgets and offline behavior. Invite testers only after this pass.

See [release procedure](RELEASE.md), [signing](ANDROID_RELEASE_SIGNING.md), [Data safety guide](DATA_SAFETY_DECLARATION_GUIDE.md) and [known issues](BUGS.md).
