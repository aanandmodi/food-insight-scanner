# Google Play Data safety declaration guide

Use this as a worksheet, not a prefilled declaration. The Play Console answers must reflect the **deployed build**, effective SDK settings and actual provider behavior. Compare every category with [Google's User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311), [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469), [account deletion rules](https://support.google.com/googleplay/android-developer/answer/13327111), and [Health Content and Services policy](https://support.google.com/googleplay/android-developer/answer/16679511).

## Review before entering answers

| Play category to review | App data and path |
| --- | --- |
| Personal info | Email, name, profile photo, age/birth date, Google account identifiers |
| Health and fitness | Weight, height, health conditions, allergies, diet goals/preferences, meal history, nutrition totals, Health Connect steps/active calories |
| App activity | Scans, product history, shopping items, AI questions, meal plans |
| Photos and videos | Optional user images in private storage; confirm current UI path and permissions |
| App info/performance and device identifiers | Crashlytics diagnostics, opt-in Firebase Analytics events and app-instance identifier, App Check and Firebase operational metadata |

For each item, determine whether it is collected off device, shared under Google's definitions, required or optional, encrypted in transit, used for app function/analytics/fraud prevention, and how deletion is requested. Firebase, Supabase, Groq and Open Food Facts are service recipients; provider contracts and Google definitions decide whether a particular transfer is reported as “sharing.” The barcode is sent to Open Food Facts through the backend; canonical product cache is shared across users without UID. Do not mark synced meals, profile or activity as ephemeral.

The app provides Settings → Delete Account. Play also requires a working public web resource for deletion requests after uninstall; deploy `legal/delete-account.html` and add its final HTTPS URL. Deploy `legal/privacy.html` to a publicly accessible, non-geofenced HTTPS URL and put it in the store listing. The policy must identify Food Insight and match Health Connect use. Explain any retention exceptions honestly. If the web request is handled by email, staff must monitor and complete it.

Complete the separate Health apps declaration for Nutrition and Weight Management and Activity and Fitness. Disclose only the Health Connect permission types actually requested. Verify the release manifest after dependency merging before submitting.
