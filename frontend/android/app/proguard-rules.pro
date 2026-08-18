# ─────────────────────────────────────────────────────────────────────────────
# ProGuard / R8 Rules for Food Insight Scanner
# Prevents stripping of critical reflection & JNI classes during code obfuscation
# ─────────────────────────────────────────────────────────────────────────────

# ── Flutter Engine & Embedding ──
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Google Play Services & Google Sign-In ──
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# ── Firebase Core, Auth, Firestore, Storage, Functions ──
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class io.flutter.plugins.firebaseauth.** { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }
-keep class io.flutter.plugins.firebase.firestore.** { *; }
-keep class io.flutter.plugins.firebase.storage.** { *; }
-keep class io.flutter.plugins.firebase.functions.** { *; }
-dontwarn com.google.firebase.**

# ── Supabase & Ktor & Kotlin Serialization ──
-keep class io.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
    @kotlinx.serialization.Serializable <fields>;
}
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# ── OkHttp & Retrofit & Networking ──
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── SQLite (sqflite) ──
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ── Health & Pedometer & Hardware Sensors ──
-keep class androidx.health.** { *; }
-keep class androidx.health.connect.client.** { *; }
-dontwarn androidx.health.**
-keep class com.cachet.health.** { *; }
-keep class com.example.pedometer.** { *; }

# ── Mobile Scanner & CameraX ──
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── Home Widgets & Android AppWidgets ──
-keep public class * extends android.appwidget.AppWidgetProvider {
    *;
}
-keep class com.food_insight_scanner.app.**WidgetProvider { *; }
-keep class es.antonborri.home_widget.** { *; }

# ── AndroidX & Multidex ──
-keep class androidx.multidex.** { *; }
-keep class androidx.core.** { *; }
-keep class androidx.annotation.** { *; }
-dontwarn androidx.**

# ── Desugaring (Java 8/11/17 APIs on older Android) ──
-keep class j$.** { *; }
-keep class java.time.** { *; }
-dontwarn j$.**
-dontwarn java.time.**

# ── Stripe (if present) ──
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-keep class com.stripe.** { *; }