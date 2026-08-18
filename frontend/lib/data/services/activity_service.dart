import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityService {
  final Health _health = Health();
  StreamSubscription<StepCount>? _stepCountStream;
  bool _isConfigured = false;
  
  // Expose step count stream for real-time updates from pedometer
  final StreamController<int> _pedometerStepsController = StreamController<int>.broadcast();
  Stream<int> get pedometerSteps => _pedometerStepsController.stream;

  ActivityService() {
    _safeConfigure();
  }

  void _safeConfigure() {
    try {
      _health.configure();
      _isConfigured = true;
    } catch (e) {
      debugPrint("Health configure error (non-fatal): $e");
    }
  }

  /// Initializes the hardware pedometer (if available)
  Future<void> initPedometer() async {
    try {
      bool granted = await _requestActivityRecognition();
      if (!granted) return;

      _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
        if (!_pedometerStepsController.isClosed) {
          _pedometerStepsController.add(event.steps);
        }
      }, onError: (error) {
        debugPrint("Pedometer stream error (non-fatal): $error");
      });
    } catch (e) {
      debugPrint("Error initializing pedometer (non-fatal): $e");
    }
  }

  /// Fetches daily activity from Health Connect (Android) or Apple Health (iOS)
  Future<Map<String, int>> syncHealthData() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    
    int steps = 0;
    int activeCalories = 0;

    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];

    try {
      if (!_isConfigured) {
        _safeConfigure();
      }

      bool hasPermission = false;
      try {
        hasPermission = await _health.hasPermissions(types) ?? false;
        if (!hasPermission) {
          hasPermission = await _health.requestAuthorization(types);
        }
      } catch (e) {
        debugPrint('Health authorization check error (non-fatal): $e');
        hasPermission = false;
      }

      if (hasPermission) {
        // Fetch steps
        try {
          int? stepsData = await _health.getTotalStepsInInterval(midnight, now);
          if (stepsData != null) {
            steps = stepsData;
          }
        } catch (e) {
          debugPrint('Error getting total steps: $e');
        }

        // Fetch active energy burned
        try {
          List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
            types: [HealthDataType.ACTIVE_ENERGY_BURNED], 
            startTime: midnight, 
            endTime: now
          );
          
          for (var point in healthData) {
            if (point.value is NumericHealthValue) {
              activeCalories += (point.value as NumericHealthValue).numericValue.toInt();
            }
          }
        } catch (e) {
          debugPrint('Error getting active energy burned: $e');
        }
      }
    } catch (e) {
      debugPrint("Exception in syncHealthData (non-fatal): $e");
    }

    return {
      'steps': steps,
      'activeCalories': activeCalories,
    };
  }

  Future<bool> _requestActivityRecognition() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.activityRecognition.status;
        if (!status.isGranted) {
          status = await Permission.activityRecognition.request();
        }
        return status.isGranted;
      } else if (Platform.isIOS) {
        var status = await Permission.sensors.status;
        if (!status.isGranted) {
          status = await Permission.sensors.request();
        }
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
    return false;
  }

  void dispose() {
    try {
      _stepCountStream?.cancel();
      _pedometerStepsController.close();
    } catch (_) {}
  }
}
