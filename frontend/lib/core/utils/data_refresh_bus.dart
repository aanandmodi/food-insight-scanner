import 'package:flutter/foundation.dart';

/// A tiny app-wide "something changed" bus.
///
/// Meals can be logged from four different places (Diet Log, Product Details,
/// the AI chat's auto-logger, and the Meal Planner) and scans from two. Before
/// this, none of those writes told the other screens, so the dashboard and diet
/// log kept showing stale totals until the user manually pulled to refresh.
///
/// Screens `addListener` to the relevant notifier in `initState` and reload.
/// Writers call [DataRefreshBus.dietLogChanged] / [scanHistoryChanged] after a
/// successful write.
class DataRefreshBus {
  DataRefreshBus._();

  /// Bumped whenever a diet entry is created, updated or deleted.
  static final ValueNotifier<int> dietLogRevision = ValueNotifier<int>(0);

  /// Bumped whenever scan history changes.
  static final ValueNotifier<int> scanHistoryRevision = ValueNotifier<int>(0);

  /// Bumped whenever the user profile (goals, weight, targets) changes.
  static final ValueNotifier<int> profileRevision = ValueNotifier<int>(0);

  static void dietLogChanged() => dietLogRevision.value++;
  static void scanHistoryChanged() => scanHistoryRevision.value++;
  static void profileChanged() => profileRevision.value++;
}
