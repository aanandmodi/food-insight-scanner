import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../services/activity_service.dart';

class ActivityProvider extends ChangeNotifier {
  final ActivityService _activityService = ActivityService();

  int _steps = 0;
  int _activeCalories = 0;
  double _distanceKm = 0.0;
  bool _isLoading = false;

  int _dailyStepGoal = 10000;
  int _dailyCalorieGoal = 400;
  double _dailyDistanceGoal = 7.5;

  bool _hasHealthConnectSteps = false;
  bool _hasHealthConnectCalories = false;

  int? _initialBootSteps;
  int _initialBaseSteps = 0;

  /// Day the baseline above belongs to. Without this the Health-Connect branch
  /// kept adding today's delta to yesterday's total whenever the app stayed
  /// open across midnight, so the ring opened the new day already full.
  String? _baselineDate;

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int get steps => _steps;
  int get activeCalories => _activeCalories;
  double get distanceKm => _distanceKm;
  bool get isLoading => _isLoading;

  int get dailyStepGoal => _dailyStepGoal;
  int get dailyCalorieGoal => _dailyCalorieGoal;
  double get dailyDistanceGoal => _dailyDistanceGoal;

  StreamSubscription<int>? _pedometerSubscription;

  ActivityProvider() {
    // Run initialization asynchronously after widget construction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initActivity();
    });
  }

  Future<void> _initActivity() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Sync with Health Connect / Apple Health for OS aggregated daily data
      final healthData = await _activityService.syncHealthData();

      if (healthData['steps'] != null && healthData['steps']! > 0) {
        _steps = healthData['steps']!;
        _hasHealthConnectSteps = true;
      }

      if (healthData['activeCalories'] != null && healthData['activeCalories']! > 0) {
        _activeCalories = healthData['activeCalories']!;
        _hasHealthConnectCalories = true;
      } else {
        _activeCalories = (_steps * 0.042).round();
      }

      _distanceKm = _steps * 0.000762;

      _isLoading = false;
      notifyListeners();
      _syncToHomeWidget();

      // 2. Start hardware pedometer stream for real-time live updates
      await _activityService.initPedometer();
      _pedometerSubscription = _activityService.pedometerSteps.listen((cumulativeBootSteps) async {
        _handlePedometerEvent(cumulativeBootSteps);
      });
    } catch (e) {
      debugPrint('ActivityProvider initialization error (non-fatal): $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handlePedometerEvent(int cumulativeBootSteps) async {
    try {
      final todayStr = _dayKey(DateTime.now());

      // Day rolled over while the app was open: today starts from zero and the
      // boot counter becomes the new reference point. Health Connect's own
      // aggregate for the new day is picked up by the next refresh()/resync.
      if (_baselineDate != null && _baselineDate != todayStr) {
        _initialBootSteps = cumulativeBootSteps;
        _initialBaseSteps = 0;
        _steps = 0;
        _activeCalories = 0;
        _distanceKm = 0.0;
      }
      _baselineDate = todayStr;

      if (_initialBootSteps == null) {
        _initialBootSteps = cumulativeBootSteps;
        _initialBaseSteps = _steps;
      }

      int deltaFromAppOpen = cumulativeBootSteps - _initialBootSteps!;
      if (deltaFromAppOpen < 0) {
        // Handle phone reboot while app running
        _initialBootSteps = cumulativeBootSteps;
        _initialBaseSteps = _steps;
        deltaFromAppOpen = 0;
      }

      if (_hasHealthConnectSteps) {
        _steps = _initialBaseSteps + deltaFromAppOpen;
      } else {
        // Fallback: use SharedPreferences to calculate steps from midnight baseline
        final prefs = await SharedPreferences.getInstance();
        final savedDate = prefs.getString('pedometer_today_date');
        int? startSteps = prefs.getInt('pedometer_today_start_steps');

        if (savedDate != todayStr || startSteps == null || startSteps > cumulativeBootSteps) {
          startSteps = cumulativeBootSteps;
          await prefs.setString('pedometer_today_date', todayStr);
          await prefs.setInt('pedometer_today_start_steps', startSteps);
        }

        final todayPedometerSteps = math.max(0, cumulativeBootSteps - startSteps);
        _steps = math.max(_initialBaseSteps + deltaFromAppOpen, todayPedometerSteps);
      }

      if (!_hasHealthConnectCalories) {
        _activeCalories = (_steps * 0.042).round();
      }
      _distanceKm = _steps * 0.000762;

      notifyListeners();
      _syncToHomeWidget();
    } catch (e) {
      debugPrint('Error handling pedometer event: $e');
    }
  }

  Future<void> refresh() async {
    try {
      final healthData = await _activityService.syncHealthData();
      bool changed = false;
      if (healthData['steps'] != null && healthData['steps']! > _steps) {
        _steps = healthData['steps']!;
        _hasHealthConnectSteps = true;
        changed = true;
      }
      if (healthData['activeCalories'] != null && healthData['activeCalories']! > _activeCalories) {
        _activeCalories = healthData['activeCalories']!;
        _hasHealthConnectCalories = true;
        changed = true;
      }
      if (!_hasHealthConnectCalories) {
        final newCal = (_steps * 0.042).round();
        if (newCal != _activeCalories) {
          _activeCalories = newCal;
          changed = true;
        }
      }
      final newDist = _steps * 0.000762;
      if ((newDist - _distanceKm).abs() > 0.05) {
        _distanceKm = newDist;
        changed = true;
      }

      if (changed) {
        notifyListeners();
        _syncToHomeWidget();
      }
    } catch (e) {
      debugPrint('Error refreshing activity data: $e');
    }
  }

  Future<void> _syncToHomeWidget() async {
    try {
      await HomeWidget.saveWidgetData<int>('steps', _steps);
      await HomeWidget.saveWidgetData<int>('steps_goal', _dailyStepGoal);
      await HomeWidget.saveWidgetData<int>('active_calories', _activeCalories);
      await HomeWidget.saveWidgetData<int>('active_calories_goal', _dailyCalorieGoal);
      await HomeWidget.saveWidgetData<double>('distance_km', _distanceKm);
      await HomeWidget.updateWidget(name: 'CalorieGraphWidgetProvider');
    } catch (e) {
      debugPrint('Failed to sync graph widget data: $e');
    }
  }

  @override
  void dispose() {
    _pedometerSubscription?.cancel();
    _activityService.dispose();
    super.dispose();
  }
}
