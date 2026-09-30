# Product scope

Food Insight helps a user scan a packaged food barcode, inspect Open Food Facts nutrition and ingredients, see a deterministic Personal Food Fit assessment against their saved preferences, and optionally log a chosen portion. Scan history, diet log, shopping list and daily activity provide context. AI chat, meal estimation and meal planning are optional explanation/suggestion tools with daily limits.

## Beta promises

- Allergen status distinguishes confirmed ingredients, possible traces, no detected conflicts and insufficient data. A serious allergy requires checking the physical package.
- Nutrition is shown per 100 g with explicit units and unknown values. Sodium is milligrams per 100 g in the canonical model. Logged portions use a user-entered gram amount.
- Food Fit reports reasons, cautions, confidence and unknowns. Confirmed allergen conflicts override a numeric score.
- A barcode with no Open Food Facts record shows a recoverable state. Previously saved product facts can be opened offline.
- Health Connect access is optional and explicitly requested; phone step-counter calories and distance are estimates.

## Beta exclusions

Healthy alternatives are hidden because AI-generated products are not verified against a catalogue. OCR, image AI, notifications, unverifiable micronutrient claims and Billing are not part of this beta. Entitlement and feature flag abstractions exist for later work; no critical allergen warnings are paywalled. No diagnosis, treatment or clinical safety claim is made.

## External limitations

Open Food Facts is community contributed and can be incomplete or wrong. AI may make mistakes and is subject to quota/provider availability. Supabase synchronization requires network access, but the SQLite outbox preserves UID-scoped edits locally until sync. Release-device and Play Console behavior require manual verification before sending to testers.

Open Food Facts [documents](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/) its database as ODbL, individual contents as DbCL and product images as CC BY-SA, subject to other image rights. Its [API guidance](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/) describes a 15 product reads/minute/IP limit and asks for an identifying User-Agent. The backend uses a 12/minute shared lookup budget and a seven-day canonical cache. Review the licensing implications before redistributing a substantial derived cache.
