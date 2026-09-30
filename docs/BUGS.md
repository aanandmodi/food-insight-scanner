# Known issues and launch gates

| Severity | Issue | Required check or action |
| --- | --- | --- |
| Blocker | The new Supabase Free Edge backend is not deployed; its handlers and adapter pass local tests. Firebase intentionally remains on Spark. | Sign in to Supabase CLI, apply deletion migration, deploy Edge, set secrets and run a disposable account end to end. |
| Blocker | Play Integrity/App Check and Google Sign-In require registered signing certificates. | Test a Play-installed release on a physical Android device. |
| Blocker | Account deletion is only locally compiled; Supabase cleanup and external request handling are not integration tested. | Test with email, Google and guest accounts including rows, images and failed/retried cleanup. |
| Blocker | Legal pages are deployed and return HTTP 200; URLs still need entering in Play. | Use the published URLs in the Play listing; they are already app defaults. |
| High | Historical Supabase ai-proxy may remain deployed with Groq access. | Deploy the 410 response or remove the function and old secret after migration. |
| High | `npm audit` reports two moderate transitive findings in backend dependencies. | Review upstream patched releases and upgrade after a focused regression pass. |
| Medium | Android widget/privacy behavior needs device QA, including account switches. | Exercise all widget sizes and sign-out. |
| Medium | Large text/TalkBack, low-end performance and Health Connect permission denial are unverified on devices. | Complete the QA matrix. |
| Medium | Open Food Facts completeness and source license treatment need ongoing review. | Verify attribution and ODbL obligations for any redistributed cache. |

No claim of beta readiness is made until these gates are closed. Issue status should be updated with evidence in the release record.
