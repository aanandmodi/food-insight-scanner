import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../services/activity_service.dart';
import '../../services/user_session.dart';
import '../../services/user_data_service.dart';
import '../../services/user_preferences.dart';

enum ActivityDataSource { none, healthConnect, pedometerEstimate }

class ActivityProvider extends ChangeNotifier {
  final _activityService = ActivityService();
  ActivityDataSource source = ActivityDataSource.none;
  int _steps = 0;
  int _activeCalories = 0;
  double _distanceKm = 0;
  bool _isLoading = false;
  bool _hasActiveCalories = false;
  bool _disposed = false;
  int? _lastSensor;
  String _date = '';
  DateTime? _lastSave;
  StreamSubscription<int>? _subscription;
  int get steps => _steps;
  int get activeCalories => _activeCalories;
  double get distanceKm => _distanceKm;
  bool get isLoading => _isLoading;
  bool get hasActiveCalories =>
      source == ActivityDataSource.pedometerEstimate || _hasActiveCalories;
  int get dailyStepGoal => 10000;
  int get dailyCalorieGoal => 400;
  double get dailyDistanceGoal => 7.5;

  ActivityProvider() {
    UserSession.instance.addListener(_accountChanged);
    scheduleMicrotask(_accountChanged);
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _accountChanged() async {
    source = ActivityDataSource.none;
    _steps = 0;
    _activeCalories = 0;
    _distanceKm = 0;
    _hasActiveCalories = false;
    _lastSensor = null;
    _lastSave = null;
    _date = DateTime.now().toIso8601String().split('T')[0];
    _notify();
    if (UserSession.instance.uid == null) return;
    final session = UserSession.instance.capture();
    _isLoading = true;
    try {
      final saved = await UserDataService().getActivity(_date);
      final preferences = await UserPreferences.getInstance();
      if (!session.isActive || _disposed) return;
      final sourceName =
          preferences.getString('activity_source') ?? saved?['source'];
      source = ActivityDataSource.values.firstWhere(
          (value) => value.name == sourceName,
          orElse: () => ActivityDataSource.none);
      _steps = (saved?['steps'] as num?)?.toInt() ?? 0;
      _activeCalories = (saved?['activeCalories'] as num?)?.toInt() ?? 0;
      _distanceKm = (saved?['distanceKm'] as num?)?.toDouble() ?? 0;
      _hasActiveCalories = saved?['hasActiveCalories'] == true;
      if (_subscription == null) {
        if (source == ActivityDataSource.pedometerEstimate) {
          await _activityService.initPedometer();
        }
        if (!session.isActive || _disposed) return;
        _subscription = _activityService.pedometerSteps.listen(_onSteps);
      }
      await _widget(session);
    } catch (e) {
      debugPrint('Activity load: $e');
    } finally {
      if (session.isActive) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void _onSteps(int sensor) {
    if (_disposed || UserSession.instance.uid == null) return;
    if (source != ActivityDataSource.pedometerEstimate) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_date != today) {
      _accountChanged();
      return;
    }
    final delta = _lastSensor == null ? 0 : sensor - _lastSensor!;
    _lastSensor = sensor;
    if (delta <= 0) return;
    if (source == ActivityDataSource.healthConnect) return;
    source = ActivityDataSource.pedometerEstimate;
    _steps += delta;
    _activeCalories = (_steps * 0.042).round();
    _distanceKm = _steps * 0.000762;
    _notify();
    final session = UserSession.instance.capture();
    _widget(session);
    if (_lastSave == null ||
        DateTime.now().difference(_lastSave!) > const Duration(minutes: 1)) {
      _lastSave = DateTime.now();
      _save(session);
    }
  }

  Future<void> _save(SessionToken session) async {
    try {
      await UserDataService().saveActivity({
        'steps': _steps,
        'activeCalories': hasActiveCalories ? _activeCalories : null,
        'source': source.name,
        'distanceKm': _distanceKm,
        'hasActiveCalories': hasActiveCalories
      }, session);
    } catch (e) {
      debugPrint('Activity sync: $e');
    }
  }

  // Health Connect import only follows an explicit refresh by the user.
  Future<void> disconnect() async {
    if (_isLoading) return;
    final session = UserSession.instance.capture();
    await _activityService.disconnect(
        revokeHealth: source == ActivityDataSource.healthConnect);
    session.check();
    source = ActivityDataSource.none;
    // Preserve the last imported daily totals; clear only the current display.
    await _save(session);
    session.check();
    _lastSensor = null;
    _steps = 0;
    _activeCalories = 0;
    _distanceKm = 0;
    _hasActiveCalories = false;
    final preferences = await UserPreferences.getInstance();
    session.check();
    await preferences.setString('activity_source', source.name);
    _notify();
    await _widget(session);
  }

  Future<void> refresh({bool requestPermission = false}) async {
    if (_isLoading) return;
    final session = UserSession.instance.capture();
    _isLoading = true;
    _notify();
    try {
      final data = await _activityService.syncHealthData(
          requestPermission: requestPermission);
      if (!session.isActive || _disposed) return;
      if (data.isEmpty && !requestPermission) return;
      source = ActivityDataSource.healthConnect;
      _steps = data['steps'] ?? 0;
      _activeCalories = data['activeCalories'] ?? 0;
      _hasActiveCalories = data.containsKey('activeCalories');
      _distanceKm = _steps * 0.000762;
      _notify();
      final preferences = await UserPreferences.getInstance();
      session.check();
      await preferences.setString('activity_source', source.name);
      await _save(session);
      await _widget(session);
    } finally {
      if (session.isActive && !_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> connectPedometer() async {
    if (_isLoading) return;
    final session = UserSession.instance.capture();
    await _activityService.initPedometer(requestPermission: true);
    session.check();
    source = ActivityDataSource.pedometerEstimate;
    _lastSensor = null;
    final preferences = await UserPreferences.getInstance();
    session.check();
    await preferences.setString('activity_source', source.name);
    _notify();
    await _save(session);
  }

  Future<void> _widget(SessionToken session) async {
    try {
      session.check();
      await HomeWidget.saveWidgetData<int>('steps', _steps);
      session.check();
      await HomeWidget.saveWidgetData<int>('active_calories', _activeCalories);
      session.check();
      await HomeWidget.saveWidgetData<double>('distance_km', _distanceKm);
      session.check();
      await HomeWidget.updateWidget(
          qualifiedAndroidName:
              'com.food_insight_scanner.app.CalorieGraphWidgetProvider');
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    UserSession.instance.removeListener(_accountChanged);
    _subscription?.cancel();
    _activityService.dispose();
    super.dispose();
  }
}
