import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// One native initialization at a time. A UI timeout does not start a second
/// platform-channel initialization while the original call is still running.
class FirebaseBootstrap {
  static final ready = ValueNotifier<bool>(false);
  static Future<void>? _pending;
  static Object? lastError;

  static Future<bool> ensureReady() async {
    _pending ??= _initialize();
    try {
      await _pending!.timeout(const Duration(seconds: 20));
      return ready.value;
    } catch (error) {
      lastError = error;
      return false;
    }
  }

  static Future<void> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode || const bool.fromEnvironment('QA_BUILD')
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
      );
      lastError = null;
      ready.value = true;
    } catch (error) {
      lastError = error;
      // Schedule after _pending has received this future, including sync errors.
      scheduleMicrotask(() => _pending = null);
      rethrow;
    }
  }
}
