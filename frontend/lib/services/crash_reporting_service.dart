import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashReportingService {
  static bool _ready = false;
  static bool enabled = true;
  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    enabled = preferences.getBool('crash_reporting_enabled') ?? true;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode && enabled);
    _ready = true;
  }
  static Future<void> setEnabled(bool value) async {
    enabled = value;
    await (await SharedPreferences.getInstance()).setBool('crash_reporting_enabled', value);
    if (_ready) await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode && value);
  }
  static void record(Object error, StackTrace? stack, {bool fatal = false}) {
    if (!_ready || !kReleaseMode || !enabled) return;
    // Exception messages can contain prompts, emails and health records.
    // Retain the type, safe SDK code and stack, without copying those messages.
    final code = error is FirebaseException && RegExp(r'^[a-z0-9-]{1,60}$').hasMatch(error.code)
        ? ':${error.code}' : '';
    FirebaseCrashlytics.instance.recordError('${error.runtimeType}$code', stack,
        fatal: fatal, printDetails: false);
  }
}
