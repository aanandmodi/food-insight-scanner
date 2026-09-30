# Current handoff — 30 September 2026

The owner requires free services/free tiers and authorized implementation, device testing, GitHub push and correcting bot-authored commit history to `aanandmodi <aanandmodi09@gmail.com>`. Follow [free setup](FREE_TIER_SETUP.md), [release](RELEASE.md), [readiness report](BETA_READINESS_REPORT.md) and [QA](QA_MATRIX.md) for the current state. Do not enable Blaze or paid provider accounts.

# Earlier implementation context

The codebase started with overlapping direct AI paths, ambiguous sodium units, permissive canonical-product rules and legacy user-data locations. The current work keeps Flutter, Provider, Firebase Auth/Functions/Firestore, Supabase user records, SQLite, mobile_scanner and Health Connect. Existing visual identity and navigation are retained.

The source code is authoritative. Earlier repository documents describe a direct Groq client and older Firestore-only user storage; those descriptions are obsolete. `docs/REPAIR_AND_RELEASE.md` describes prior UID-scoped Supabase work, but its AI_PROXY_URL note is superseded by the Firebase `aiTask` callable. The Supabase `ai-proxy` source now returns 410 and still needs deployment or removal in the Supabase Dashboard.

See [architecture](ARCHITECTURE.md), [product](PRODUCT.md), [data model](DATA_MODEL.md), [privacy map](PRIVACY_DATA_MAP.md), and [known issues](BUGS.md). This branch includes pre-existing uncommitted work; inspect the full diff before selectively committing.
