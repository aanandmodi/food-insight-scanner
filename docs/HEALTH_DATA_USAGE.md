# Health and activity data

Food Insight requests Health Connect read access for **steps** and **active calories burned** only after the user selects “Connect Health” from the activity prompt. These values support the daily activity card and are saved as daily account totals. The scanner, Food Fit and diet log can be used without a Health Connect connection. Android's Health Connect controls revocation.

The alternative phone step counter may require `ACTIVITY_RECOGNITION`; calories and distance derived from steps are estimates, labeled in the UI. Health Connect distance shown by the current app is also estimated from steps. Activity source is persisted with the total so a phone estimate does not overwrite a Health Connect reading. The provider does not silently request Health Connect permission during startup.

The app does not read heart rate, medical records or diagnoses from Health Connect, and does not write data back to Health Connect. User-entered conditions and allergies are separate profile fields. Health data is not used for advertising or sold. Deleting the account removes synced daily activity records and local cache through the cleanup path; revoking Android permission stops new reads but does not automatically delete previously synced totals.

Before Play closed testing, verify permission dialog text and behavior on Android 8, Android 13 and current Android, with Health Connect installed/unavailable and permission granted/denied. Declare Nutrition and Weight Management and Activity and Fitness features in the Play Health apps declaration, and explain the exact Health Connect permissions in the declaration.
