import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UsageEvent {
  scanStarted,
  scanSucceeded,
  scanNotFound,
  scanFailed,
  mealLogged,
  aiRequested,
  aiSucceeded,
  aiLimited,
  aiFailed
}

/// Event names only: no free-text parameters, user IDs, foods or health data.
/// Disabled before native startup and until the user opts in in Settings.
class AnalyticsService {
  static bool enabled = false;
  static bool _ready = false;
  static Future<void> initialize() async {
    enabled = (await SharedPreferences.getInstance())
            .getBool('usage_analytics_enabled') ??
        false;
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(enabled && kReleaseMode);
    await FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        analyticsStorageConsentGranted: enabled);
    _ready = true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    await (await SharedPreferences.getInstance())
        .setBool('usage_analytics_enabled', value);
    if (!_ready) return;
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(value && kReleaseMode);
    await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: value,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false);
    if (!value) await FirebaseAnalytics.instance.resetAnalyticsData();
  }

  static Future<void> record(UsageEvent event) async {
    if (!_ready || !enabled || !kReleaseMode) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
          name: event.name.replaceAllMapped(
              RegExp(r'[A-Z]'), (match) => '_${match[0]!.toLowerCase()}'));
    } catch (_) {/* Diagnostics must never interrupt a user action. */}
  }
}
