# Firebase App Check setup

Flutter initializes App Check before auth-dependent callables. Debug builds use the debug provider; release Android builds use Play Integrity. The v2 `scanProduct`, `aiTask` and `requestAccountDeletion` callables set `enforceAppCheck: true`.

1. In Firebase Console → App Check, register the Android app `com.food_insight_scanner.app` with Play Integrity. Link the correct Google Play app and check project/API prerequisites. Register only known local debug tokens for development; do not commit them.
2. Add the release upload certificate SHA-1/SHA-256 to Firebase Android settings for Google Sign-In. After Play App Signing is enabled, also add the **Play app-signing** certificate fingerprints and redownload `google-services.json` if Firebase requires it.
3. Deploy the Functions with enforcement and install a release from the Play closed track on a physical device. Verify valid calls succeed and invalid/no App Check requests fail. Inspect App Check metrics before expanding enforcement to other Firebase products.
4. The debug provider writes a debug token to local logs when needed. Add it to Firebase Console for test devices. Never register a public token or package it in the release.

App Check reduces automated abuse; it is not a substitute for Auth, UID checks, quotas or product-write rules. A missing Play Integrity registration can make the release unable to scan or use AI, so this is a launch gate.
