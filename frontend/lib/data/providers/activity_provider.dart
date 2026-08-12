import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/activity_service.dart';

class ActivityProvider extends ChangeNotifier {
  final ActivityService _activityService = ActivityService();
  
  int _steps = 0;
  int _activeCalories = 0;
  bool _isLoading = true;
  int _dailyStepGoal = 10000;
  
  int get steps => _steps;
  int get activeCalories => _activeCalories;
  bool get isLoading => _isLoading;
  int get dailyStepGoal => _dailyStepGoal;

  StreamSubscription<int>? _pedometerSubscription;

  ActivityProvider() {
    _initActivity();
  }

  Future<void> _initActivity() async {
    _isLoading = true;
    notifyListeners();

    // 1. First sync with Health Connect / Apple Health for total daily data
    final healthData = await _activityService.syncHealthData();
    if (healthData['steps']! > 0) {
      _steps = healthData['steps']!;
    }
    if (healthData['activeCalories']! > 0) {
      _activeCalories = healthData['activeCalories']!;
    }

    _isLoading = false;
    notifyListeners();

    // 2. Start hardware pedometer for live updates (if Health API doesn't provide them fast enough)
    await _activityService.initPedometer();
    _pedometerSubscription = _activityService.pedometerSteps.listen((newSteps) {
      // The pedometer returns total steps since boot. We need to handle this properly,
      // but for simplicity in this demo, if the pedometer steps exceed the health steps, we update it.
      // A more robust app would track initial boot steps at midnight.
      if (newSteps > _steps) {
        _steps = newSteps;
        notifyListeners();
      }
    });
  }
  
  Future<void> refresh() async {
     final healthData = await _activityService.syncHealthData();
     bool changed = false;
     if (healthData['steps']! > _steps) {
       _steps = healthData['steps']!;
       changed = true;
     }
     if (healthData['activeCalories']! > _activeCalories) {
       _activeCalories = healthData['activeCalories']!;
       changed = true;
     }
     if (changed) {
       notifyListeners();
     }
  }

  @override
  void dispose() {
    _pedometerSubscription?.cancel();
    _activityService.dispose();
    super.dispose();
  }
}
