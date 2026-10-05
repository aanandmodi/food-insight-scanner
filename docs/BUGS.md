# Known issues and launch gates

| Severity | Issue | Required check or action |
| --- | --- | --- |
| Closed | Supabase Free Edge, deletion migration and server credentials are deployed. Firebase remains Spark. | Live AI/catalog/auth/App Check/deletion checks passed; repeat after backend changes. |
| Blocker | Play Integrity/App Check and Google Sign-In require registered signing certificates. | Test a Play-installed release on a physical Android device. |
| High | Live backend deletion and phone email/upgraded-guest deletion passed, including UID and all seven private table cleanup. | Complete Google/image/failure-retry coverage; operate the external deletion inbox. |
| Blocker | Legal pages are deployed and return HTTP 200; URLs still need entering in Play. | Use the published URLs in the Play listing; they are already app defaults. |
| Closed | Historical Supabase ai-proxy is deployed as HTTP 410. | Keep the authenticated shared Edge route as the active AI endpoint. |
| Closed | Backend multipart/UUID transitive vulnerabilities were patched; `npm audit` reports zero findings on 5 October. | Preserve patched dependency resolutions and rerun the audit after dependency changes. |
| Medium | Android widget/privacy behavior needs device QA, including account switches. | Exercise all widget sizes and sign-out. |
| Medium | Normal/2x layouts, connected-phone chat/diet performance and Health Connect import passed. TalkBack, low-end hardware and fresh permission scenarios remain. | Complete the QA matrix. |
| Medium | Open Food Facts completeness and source license treatment need ongoing review. | Verify attribution and ODbL obligations for any redistributed cache. |

No claim of beta readiness is made until these gates are closed. Issue status should be updated with evidence in the release record.
