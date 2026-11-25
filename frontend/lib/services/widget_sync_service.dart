import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../core/utils/data_refresh_bus.dart';
import '../core/utils/user_utils.dart';
import '../models/user_profile.dart';
import 'user_data_service.dart';
import 'user_session.dart';

/// Centralized service to keep all Android Home Screen Widgets synchronized
/// with the app's diet logs, activity counters, and user profile goals.
class WidgetSyncService {
  static bool _initialized = false;
  static bool _isSyncing = false;
  static bool _pendingResync = false;

  WidgetSyncService._();

  /// Starts listening to global refresh and session events so home widgets
  /// stay synchronized when meals, goals, or accounts change.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    DataRefreshBus.dietLogRevision.addListener(() {
      syncNow();
    });

    DataRefreshBus.profileRevision.addListener(() {
      syncNow();
    });

    UserSession.instance.addListener(() {
      if (UserSession.instance.uid != null) {
        syncNow();
      }
    });

    if (UserSession.instance.uid != null) {
      syncNow();
    }
  }

  /// Calculates today's consumed macros & calories and updates home widgets.
  static Future<void> syncNow() async {
    if (UserSession.instance.uid == null) return;
    if (_isSyncing) {
      _pendingResync = true;
      return;
    }
    _isSyncing = true;
    try {
      final session = UserSession.instance.capture();
      final db = UserDataService();
      final today = DateTime.now().toIso8601String().split('T')[0];

      final logs = await db.cachedDiet(today);
      session.check();

      Map<String, dynamic>? profileMap;
      try {
        profileMap = await db.getUserProfile();
      } catch (_) {}
      session.check();

      Map<String, dynamic>? activity;
      try {
        activity = await db.getActivity(today);
      } catch (_) {}
      session.check();

      int calConsumed = 0;
      double carbsConsumed = 0.0;
      double proteinConsumed = 0.0;
      double fatConsumed = 0.0;

      for (final log in logs) {
        calConsumed += (log['calories'] as num?)?.toInt() ?? 0;
        carbsConsumed += (log['carbs'] as num?)?.toDouble() ?? 0.0;
        proteinConsumed += (log['protein'] as num?)?.toDouble() ?? 0.0;
        fatConsumed += (log['fat'] as num?)?.toDouble() ?? 0.0;
      }

      final parsedProfile =
          profileMap == null ? null : UserProfile.fromMap(profileMap);
      final calGoal = UserUtils.calculateTDEE(
        weightKg: parsedProfile?.weightKg,
        heightCm: parsedProfile?.heightCm,
        age: parsedProfile?.age ?? 25,
        gender: parsedProfile?.gender ?? '',
        activityLevel: parsedProfile?.activityLevel ?? 'moderate',
        healthGoal: parsedProfile?.healthGoals,
        customGoal: parsedProfile?.customCaloriesGoal,
      );
      final proteinGoal = UserUtils.calculateProteinGoal(
        weightKg: parsedProfile?.weightKg,
        healthGoal: parsedProfile?.healthGoals,
        customGoal: parsedProfile?.customProteinGoal,
      );
      final carbsGoal = UserUtils.calculateCarbsGoal(
        calGoal,
        customGoal: parsedProfile?.customCarbsGoal,
      );
      final fatGoal = UserUtils.calculateFatGoal(
        calGoal,
        customGoal: parsedProfile?.customFatGoal,
      );

      session.check();
      await HomeWidget.saveWidgetData<int>('calories_consumed', calConsumed);
      session.check();
      await HomeWidget.saveWidgetData<int>('calories_goal', calGoal);
      session.check();
      await HomeWidget.saveWidgetData<int>(
          'carbs_consumed', carbsConsumed.round());
      session.check();
      await HomeWidget.saveWidgetData<int>('carbs_goal', carbsGoal);
      session.check();
      await HomeWidget.saveWidgetData<int>(
          'protein_consumed', proteinConsumed.round());
      session.check();
      await HomeWidget.saveWidgetData<int>('protein_goal', proteinGoal);
      session.check();
      await HomeWidget.saveWidgetData<int>('fat_consumed', fatConsumed.round());
      session.check();
      await HomeWidget.saveWidgetData<int>('fat_goal', fatGoal);

      if (activity != null) {
        final steps = (activity['steps'] as num?)?.toInt() ?? 0;
        final activeCals = (activity['activeCalories'] as num?)?.toInt() ??
            (activity['active_calories'] as num?)?.toInt() ??
            0;
        final distanceKm = (activity['distanceKm'] as num?)?.toDouble() ??
            (activity['distance_km'] as num?)?.toDouble() ??
            0.0;
        session.check();
        await HomeWidget.saveWidgetData<int>('steps', steps);
        session.check();
        await HomeWidget.saveWidgetData<int>('active_calories', activeCals);
        session.check();
        await HomeWidget.saveWidgetData<double>('distance_km', distanceKm);
      }
      session.check();
      await HomeWidget.saveWidgetData<int>('active_calories_goal', 400);

      const widgetProviders = [
        'MacroWidgetProvider',
        'SmallWidgetProvider',
        'LargeWidgetProvider',
        'CalorieGraphWidgetProvider',
      ];

      for (final name in widgetProviders) {
        session.check();
        await HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.food_insight_scanner.app.$name',
        );
      }
    } on SessionChangedException {
      // Account switched or signed out mid-sync; ignore stale results.
    } catch (e) {
      debugPrint('WidgetSyncService.syncNow error: $e');
    } finally {
      _isSyncing = false;
      if (_pendingResync) {
        _pendingResync = false;
        if (UserSession.instance.uid != null) {
          unawaited(syncNow());
        }
      }
    }
  }
}
