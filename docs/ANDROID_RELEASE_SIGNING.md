# Android release signing

`frontend/android/app/build.gradle` requires `frontend/android/key.properties` and an existing keystore for release tasks. These files are ignored by Git. Keep encrypted backups of the upload key and credentials; do not create a new key if an existing Play app already uses an upload key without following Google's reset process.

Example `frontend/android/key.properties`:

```properties
storeFile=keystore/food-insight-upload.jks
storePassword=YOUR_PRIVATE_VALUE
keyAlias=food-insight
keyPassword=YOUR_PRIVATE_VALUE
```

From `frontend/`:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

The output is `frontend/build/app/outputs/bundle/release/app-release.aab`. Keep the matching `build/debug-info` directory private for Dart de-obfuscation. Verify the AAB's signing certificate with `jarsigner -verify -verbose -certs` and check the package/version with bundletool or Play Console. Confirm the certificate is the intended **upload key**, not Android's debug key. Google Play re-signs installed APKs with the Play app-signing key, whose SHA fingerprints must also be registered in Firebase.

Release build compilation and signature verification do not prove runtime Firebase initialization or Google Sign-In. Install through the closed track and test both on a physical device before inviting testers. Update `frontend/pubspec.yaml` version name/code for every uploaded build; current source version is `1.0.2+2003`.
