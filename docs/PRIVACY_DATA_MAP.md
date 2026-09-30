# Privacy data map

This is an implementation inventory for the beta. Verify deployed configuration, SDK collection and provider contracts before submitting Play Data safety answers. Account records are retained while the account is active; account deletion is intended to remove them. Operational provider logs may have separate retention. A user may also clear app storage or uninstall to remove local caches.

| Data | Purpose and path | Recipients/storage | Deletion |
| --- | --- | --- | --- |
| Firebase UID, email, Google profile name/photo or guest identity | Authentication and account linking | Firebase Auth; profile copy in Supabase/legacy Firestore and local cache | Auth and profile cleanup |
| Optional age, height, weight, gender, conditions, goals, dietary preferences and allergies | Calorie targets, Food Fit, cautions and AI context when requested | Supabase `profiles`, UID-scoped SQLite; selected fields sent through Supabase Edge Functions to Groq for AI tasks | Account cleanup and local purge |
| Barcode and scan history | Product lookup and history | Barcode sent to the authenticated backend and Open Food Facts; shared canonical product cached in Firestore; history in Supabase and SQLite | History deleted with account; canonical public product cache persists without UID |
| Ingredients, product nutrition, images | Display and Food Fit | Open Food Facts, Firestore canonical cache, device cache | Cache TTL/local removal; public product cache not personal data |
| Diet entries, portions, meal plans, shopping items | User nutrition record and recommendations | Supabase and UID-scoped SQLite; legacy Firestore for migrated records | Account cleanup and local purge |
| AI chat text, meal descriptions and selected profile/product context | Answer question, estimate meal or plan | Supabase Edge Function sends to Groq; chat records can be stored in Supabase/SQLite | Account cleanup; provider operational retention must be reviewed |
| Health Connect steps and active calories | Display daily activity | Android Health Connect read with explicit permission, daily totals in Supabase/SQLite; widget snapshot on device | Revoke via Android; account cleanup and widget reset |
| Phone step counter and estimated calories/distance | Optional activity display | Sensor on device, daily totals in Supabase/SQLite and Android widget values | Account cleanup and widget reset |
| User images | Profile/scan images | Private Supabase Storage; older records may use Firebase Storage | Account cleanup of both stores |
| Crash diagnostics | Fix failures | Firebase Crashlytics in release when enabled; minimized type/code and stack, plus SDK device/app metadata | User can disable collection; retention follows Firebase settings |
| Optional feature events and pseudonymous app-instance ID | Opt-in usage counts, off by default; no account IDs, barcodes, meals, allergies or chat content | Firebase Analytics; ad identifiers/personalization and automatic screen reporting disabled | Disable/reset in Settings; provider retention settings govern previously collected events |
| App Check token and network metadata | Abuse prevention, service operation | Firebase/Google and service providers | Provider operational retention |
| Camera frames | Barcode detection | Device camera/scanner; barcode is sent after detection | Frames are not intentionally stored by the scan path |

Sharing with a service provider for app operation should be described accurately in Play Data safety according to Google's definitions. Do not claim that all data is ephemeral: profile, activity totals and history are synced. The app does not implement advertising or data sale, and the current code should be rechecked for transitive SDK behavior before final submission.
