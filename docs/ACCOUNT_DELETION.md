# Account deletion

## In-app path

Settings → Delete Account → confirmation. Email/password accounts prompt for the password. Google accounts reauthenticate with Google. Guest accounts use their current authenticated session. The Flutter client calls the shared `requestAccountDeletion` handler through Supabase Edge with Firebase Auth and App Check. The backend requires a recent login for non-guest users.

The callable runs a Supabase service-role RPC which inserts a UID deletion guard and removes seven account tables and the legacy AI quota table. It then removes objects under `users/{uid}` from private and legacy Supabase buckets, recursively deletes Firestore user and legacy records, deletes Firebase Storage objects under the UID, and finally deletes Firebase Auth. It returns success only after those operations complete. On the free deployment there is no Firebase Auth event trigger: externally requested deletion must run backend cleanup before Auth removal. The optional Firebase Functions target includes a retrying trigger. Flutter then purges UID-scoped SQLite/preferences and zeroes Android widgets. A failed backend step preserves the Auth account and reports a retryable error.

## External request

The public page is https://food-insight-scanner-app.web.app/delete-account.html. It gives an email request route for users without the app. The owner must operate that inbox, verify account ownership without asking for passwords or health details, and process requests using the same cleanup procedure. Anonymous users without the original device may be impossible to identify reliably; document and handle those requests individually. Deleting the app alone is not a server deletion request.

## Preconditions and QA

Apply `supabase/migrations/202609290001_account_deletion.sql`, configure the dedicated Firebase Admin credential in Supabase secrets (the service-role key is supplied by Supabase), and deploy the shared Edge function before exposing the feature. Test a fixture account with rows in every Supabase table, both image buckets, Firestore nested/legacy paths, Firebase Storage, and local cache. Test email, Google, guest, partial failure/retry, expired authentication and Auth Console deletion. Confirm a stale JWT cannot recreate Supabase or Firestore rows after deletion. Both stores keep a minimal backend-only UID guard. Keep evidence without retaining the fixture's sensitive data.
