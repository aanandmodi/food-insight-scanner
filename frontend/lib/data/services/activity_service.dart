import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityService {
  final Health _health = Health();
  StreamSubscription<StepCount>? _stepCountStream;
  
  // Expose step count stream for real-time updates from pedometer
  final StreamController<int> _pedometerStepsController = StreamController<int>.broadcast();
  Stream<int> get pedometerSteps => _pedometerStepsController.stream;

  ActivityService() {
    _health.configure();
  }

  /// Initializes the hardware pedometer (if available)
  Future<void> initPedometer() async {
    bool granted = await _requestActivityRecognition();
    if (!granted) return;

    try {
      _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) {
        _pedometerStepsController.add(event.steps);
      }, onError: (error) {
        print("Pedometer error: $error");
      });
    } catch (e) {
      print("Error initializing pedometer: $e");
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
      bool requested = await _health.requestAuthorization(types);
      if (requested) {
        // Fetch steps
        int? stepsData = await _health.getTotalStepsInInterval(midnight, now);
        if (stepsData != null) {
          steps = stepsData;
        }

        // Fetch active energy burned
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
      }
    } catch (e) {
      print("Exception in syncHealthData: $e");
    }

    return {
      'steps': steps,
      'activeCalories': activeCalories,
    };
  }

  Future<bool> _requestActivityRecognition() async {
    if (Platform.isAndroid) {
      var status = await Permission.activityRecognition.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      var status = await Permission.sensors.request();
      return status.isGranted;
    }
    return false;
  }

  void dispose() {
    _stepCountStream?.cancel();
    _pedometerStepsController.close();
  }
}
