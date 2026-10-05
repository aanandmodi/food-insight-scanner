import 'dart:async';
import 'dart:io';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityService {
  final Health _health;
  ActivityService({Health? health}) : _health = health ?? Health();
  StreamSubscription<StepCount>? _stepCountStream;
  bool _configured = false;
  final _steps = StreamController<int>.broadcast();
  Stream<int> get pedometerSteps => _steps.stream;

  Future<void> initPedometer({bool requestPermission = false}) async {
    if (_stepCountStream != null) return;
    final permission = Platform.isAndroid
        ? Permission.activityRecognition
        : Permission.sensors;
    var status = await permission.status;
    if (!status.isGranted && requestPermission) {
      status = await permission.request();
    }
    if (!status.isGranted) {
      if (requestPermission) {
        throw StateError(
            'Step counter permission was not granted. You can continue scanning food.');
      }
      return;
    }
    _stepCountStream = Pedometer.stepCountStream.listen((event) {
      if (!_steps.isClosed) _steps.add(event.steps);
    }, onError: (_) {});
  }

  Future<Map<String, int>> syncHealthData(
      {bool requestPermission = false}) async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
    if (Platform.isAndroid &&
        await _health.getHealthConnectSdkStatus() !=
            HealthConnectSdkStatus.sdkAvailable) {
      if (requestPermission) {
        throw StateError(
            'Health Connect is unavailable on this device. You can use the step counter or continue scanning food.');
      }
      return {};
    }
    const types = [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];
    const permissions = [HealthDataAccess.READ, HealthDataAccess.READ];
    var granted =
        await _health.hasPermissions(types, permissions: permissions) ?? false;
    if (!granted && requestPermission) {
      granted =
          await _health.requestAuthorization(types, permissions: permissions);
    }
    if (!granted) {
      if (requestPermission) {
        throw StateError(
            'Health access was not granted. You can connect later from Settings.');
      }
      return {};
    }
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final result = <String, int>{};
    final steps = await _health.getTotalStepsInInterval(midnight, now);
    if (steps != null) result['steps'] = steps.clamp(0, 200000);
    // The aggregate Dart call in health 13.1.3 omits Android's required interval.
    final data = await _health.getHealthIntervalDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startDate: midnight,
        endDate: now,
        interval: 86400);
    if (data.isNotEmpty) {
      result['activeCalories'] = data
          .where((point) => point.value is NumericHealthValue)
          .fold<num>(
              0,
              (sum, point) =>
                  sum + (point.value as NumericHealthValue).numericValue)
          .round()
          .clamp(0, 20000);
    }
    return result;
  }

  Future<void> disconnect({bool revokeHealth = true}) async {
    if (revokeHealth) {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      await _health.revokePermissions();
    }
    await _stepCountStream?.cancel();
    _stepCountStream = null;
  }

  void dispose() {
    _stepCountStream?.cancel();
    _steps.close();
  }
}
