# 🐛 Bug Tracking & Resolution Log

This document tracks known issues, workarounds, and resolved bugs for the **Food Insight Scanner** project (Flutter frontend + Firebase Cloud Functions backend).

---

## Resolved Bugs

### 🔧 Build & Compilation

| Bug | Root Cause | Resolution | Date |
|-----|-----------|------------|------|
| `MalformedJsonException` during Gradle build | Corrupted JSON files in `android/app/.cxx/` CMake cache | Delete `.cxx/` and `.gradle/` directories, rebuild | May 2026 |
| `fluttertoast` compileSdk conflict | fluttertoast requires compileSdk 36+ | Updated `compileSdk` and `targetSdk` to 36 in `build.gradle` | May 2026 |
| `BoxShadow` invalid `inset` parameter | Flutter's `BoxShadow` doesn't have an `inset` parameter | Removed the `boxShadow` from the progress track container | May 2026 |
| `EdgeInsets.symmetric(vertical: 1.5).h` type error | `.h` extension called on `EdgeInsets` instead of `double` | Changed to `EdgeInsets.symmetric(vertical: 1.5.h)` | May 2026 |

### 🔐 Authentication

| Bug | Root Cause | Resolution | Date |
|-----|-----------|------------|------|
| Firebase initialization hanging on startup | No timeout on `Firebase.initializeApp()` | Added 12-second timeout with retry mechanism | May 2026 |
| App crash when Firebase unavailable | Uncaught exceptions in auth flow | Added try-catch with graceful fallback UI and manual retry | May 2026 |
| Navigation loop after sign-in | Direct navigation to dashboard skipping profile check | Implemented `AuthGate` to check profile completeness | May 2026 |

### ☁️ Backend / Cloud Functions

| Bug | Root Cause | Resolution | Date |
|-----|-----------|------------|------|
| GROQ_API_KEY not available in Cloud Functions | Using `process.env` instead of Firebase secrets | Migrated to `defineSecret` from firebase-functions/params | May 2026 |
| Invalid AI model names causing 404 errors | Deprecated/invalid Groq model names | Updated to `llama-3.3-70b-versatile` and `llama-3.1-8b-instant` | May 2026 |
| `scanProduct` function not deployed | Missing export in `index.ts` | Added export statement to `index.ts` | May 2026 |
| TypeScript compilation errors | Type mismatches in function signatures | Fixed type annotations across all function files | May 2026 |

---

## Known Issues / Limitations

### ⚠️ Requires Action

| Issue | Impact | Workaround |
|-------|--------|------------|
| Firebase Blaze plan required for Cloud Functions | AI features (chat, meal parsing, diet plans) won't work without deployed functions | Upgrade to Blaze at https://console.firebase.google.com/project/food-insight-scanner-app/usage/details |
| Google Sign-In requires SHA fingerprints | Google auth fails on devices without registered SHA-1/SHA-256 | Add device fingerprints in Firebase Console → Project Settings → Android App |

### 📝 Low Priority

| Issue | Impact | Notes |
|-------|--------|-------|
| `flutter_markdown` package is discontinued | Still works but no future updates | Consider migrating to `flutter_markdown_plus` |
| 82 packages have newer versions available | No functionality impact | Run `flutter pub outdated` to review |
| Release APK is 82.4MB | Large for a utility app | Enable code shrinking and `minifyEnabled true` for release |
| Deprecated API warnings during build | No functionality impact | `Note: Some input files use or override a deprecated API` |

---

## How to Report Bugs

1. Check this document first for known issues
2. Open a GitHub Issue at https://github.com/aanandmodi/food-insight-scanner/issues
3. Include: steps to reproduce, expected vs actual behavior, device/OS info, error logs
