import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../services/activity_service.dart';
import '../../services/user_session.dart';
import '../../services/user_data_service.dart';

enum ActivityDataSource { none, healthConnect, pedometerEstimate }

class ActivityProvider extends ChangeNotifier {
  final _activityService = ActivityService();
  ActivityDataSource source = ActivityDataSource.none;
  int _steps = 0;
  int _activeCalories = 0;
  double _distanceKm = 0;
  bool _isLoading = false;
  bool _disposed = false;
  int? _lastSensor;
  String _date = '';
  DateTime? _lastSave;
  StreamSubscription<int>? _subscription;
  int get steps => _steps;
  int get activeCalories => _activeCalories;
  double get distanceKm => _distanceKm;
  bool get isLoading => _isLoading;
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
    _lastSensor = null;
    _lastSave = null;
    _date = DateTime.now().toIso8601String().split('T')[0];
    _notify();
    if (UserSession.instance.uid == null) return;
    final session = UserSession.instance.capture();
    _isLoading = true;
    try {
      final saved = await UserDataService().getActivity(_date);
      if (!session.isActive || _disposed) return;
      source = ActivityDataSource.values.firstWhere((value) => value.name == saved?['source'], orElse: () => ActivityDataSource.none);
      _steps = (saved?['steps'] as num?)?.toInt() ?? 0;
      _activeCalories = (saved?['activeCalories'] as num?)?.toInt() ?? 0;
      _distanceKm = (saved?['distanceKm'] as num?)?.toDouble() ?? 0;
      if (_subscription == null) {
        if (source == ActivityDataSource.pedometerEstimate) await _activityService.initPedometer();
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
        'activeCalories': _activeCalories,
        'source': source.name,
        'distanceKm': _distanceKm
      }, session);
    } catch (e) {
      debugPrint('Activity sync: $e');
    }
  }

  // Health Connect import only follows an explicit refresh by the user.
  Future<void> disconnect() async {
    final session = UserSession.instance.capture();
    await _activityService.disconnect();
    session.check();
    source = ActivityDataSource.none;
    _lastSensor = null;
    _notify();
    await _save(session);
  }

  Future<void> refresh({bool requestPermission = false}) async {
    final session = UserSession.instance.capture();
    final data = await _activityService.syncHealthData(requestPermission: requestPermission);
    if (!session.isActive || _disposed) return;
    if (data.isEmpty) return;
    source = ActivityDataSource.healthConnect;
    _steps = data['steps'] ?? _steps;
    _activeCalories = data['activeCalories'] ?? 0;
    _distanceKm = _steps * 0.000762;
    _notify();
    await _save(session);
    await _widget(session);
  }

  Future<void> connectPedometer() async {
    final session = UserSession.instance.capture();
    await _activityService.initPedometer(requestPermission: true);
    session.check();
    source = ActivityDataSource.pedometerEstimate;
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
      await HomeWidget.updateWidget(name: 'CalorieGraphWidgetProvider');
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
