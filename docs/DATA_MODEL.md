# Data model

## Canonical product (`products/{barcode}`)

The server writes `schemaVersion: 2`, `source: open_food_facts`, `sourceFetchedAt`, `dataCompleteness`, `barcode`, `name`, `brand`, `image`, `quantity`, `servingSize`, `nutriscore`, `novaGroup`, `ingredientsText`, `ingredients`, `allergens`, `traces`, and `ingredientsAnalysisTags`. `nutrition` contains `energyKcalPer100g`, `proteinGPer100g`, `carbohydratesGPer100g`, `sugarGPer100g`, `fatGPer100g`, `fiberGPer100g`, and `sodiumMgPer100g`. Missing values are `null`, never zero. Compatibility keys (`calories`, `protein`, `carbs`, `sugar`, `fat`, `fiber`, `sodium`) are emitted with the same units. Open Food Facts sodium grams per 100 g are multiplied by 1,000 for milligrams. Cache age is seven days. Only the backend can write this collection.

Legacy product caches are adapted locally. An old ambiguous `sodium` value is treated as unknown unless the explicit schema marker confirms milligrams. Per-portion values use the selected gram amount divided by 100; a missing source value stays missing.

## User data

Firebase UID is the owner key. Supabase tables `profiles`, `scans`, `diet_entries`, `shopping_items`, `meal_plans`, `chat_messages`, and `activity_logs` use `(user_id, id)` as the conflict key, `data` JSON, `updated_at`, and a `deleted` tombstone. RLS compares `user_id` to the verified Firebase JWT subject and rejects deleted accounts. SQLite `records` has the same owner/table/id key plus `dirty` and `deleted` flags for offline sync. Some legacy Firestore user collections and nested `users/{uid}` data are retained for migration and deleted by the account cleanup function. Supabase images use `users/{uid}/...` in private buckets; references are `supabase://bucket/path` and resolved to short-lived signed URLs.

## Backend control documents

`config/featureFlags` contains `aiEnabled` (required true for AI), optional `aiChatEnabled`, `mealPlannerEnabled`, and `aiDailyLimits`. The backend reads it using Admin credentials; authenticated clients may read but cannot change it. `users/{uid}/aiUsage/current` stores task counters, last-request timestamp and an expiry timestamp. Clients cannot write quota records. The server counts attempts, including provider failures, to bound cost. `serviceLimits/offLookupMinute` is a server-only shared counter limiting uncached Open Food Facts requests to 12/minute.

## Deletion

`requestAccountDeletion` deletes Supabase account rows, private images, Firestore records, Firebase Storage assets and Auth. `account_deletion_guards` keeps a minimal UID marker to stop stale JWT writes. Local account caches and widget data are removed or reset after server success. See [account deletion](ACCOUNT_DELETION.md).

Daily AI counters now use one `aiUsage/current` document per UID and overwrite counters when the UTC day changes; no paid TTL service is required. `serviceLimits/aiBudget` caps the whole app at 200 AI attempts/day and 10/minute, including provider failures. `accountDeletionGuards/{uid}` is backend-only and blocks stale Firestore tokens before cleanup begins. Supabase has a corresponding RLS deletion guard.
