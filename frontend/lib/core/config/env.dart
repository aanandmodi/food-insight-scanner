/// Build-time configuration.
///
/// SECURITY: never hardcode secrets in this file. Anything compiled into the
/// APK can be recovered with `apktool`/`strings` in seconds, so a literal here
/// is equivalent to publishing the key.
///
/// Values are injected at build time via `--dart-define`:
///
/// ```
/// flutter build apk --release \
///   --dart-define=AI_PROXY_URL=https://asia-south1-<project>.cloudfunctions.net/aiProxy
/// ```
///
/// ## Which path does the app use?
///
/// 1. `AI_PROXY_URL` set  → all AI traffic goes through your own backend, which
///    holds the Groq key server-side. **This is the only production-safe mode**
///    and the one to use for Play Store builds.
/// 2. Otherwise → the app falls back to calling Groq directly with a key the
///    *user* supplies in Settings (stored in their own SharedPreferences).
///    `GROQ_API_KEY` may be dart-defined for local development only.
class Env {
  Env._();

  /// URL of a server-side AI proxy that injects the Groq key. Preferred.
  static const String aiProxyUrl = String.fromEnvironment('AI_PROXY_URL');

  /// Development-only fallback key. Empty in release builds unless explicitly
  /// dart-defined — do NOT define it for store builds.
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  /// True when AI calls should be routed through the backend proxy.
  static bool get useAiProxy => aiProxyUrl.isNotEmpty;

  /// True when the build has no server proxy and no dev key, meaning AI
  /// features depend on the user entering their own key in Settings.
  static bool get requiresUserSuppliedKey =>
      aiProxyUrl.isEmpty && groqApiKey.isEmpty;
}
