import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:food_insight_scanner/data/services/activity_service.dart';

class _Health extends Health {
  bool granted = true;
  int authorizationCalls = 0;
  int? requestedInterval;
  @override
  Future<void> configure() async {}
  @override
  Future<bool?> hasPermissions(List<HealthDataType> types,
          {List<HealthDataAccess>? permissions}) async =>
      granted;
  @override
  Future<bool> requestAuthorization(List<HealthDataType> types,
      {List<HealthDataAccess>? permissions}) async {
    authorizationCalls++;
    return granted;
  }

  @override
  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime,
          {bool includeManualEntry = true}) async =>
      3108;
  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes(
      {required DateTime startDate,
      required DateTime endDate,
      required List<HealthDataType> types,
      required int interval,
      List<RecordingMethod> recordingMethodsToFilter = const []}) async {
    requestedInterval = interval;
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'valid steps survive a day with no calorie records using the interval API',
      () async {
    final health = _Health();
    final service = ActivityService(health: health);
    addTearDown(service.dispose);
    final data = await service.syncHealthData(requestPermission: true);
    expect(data['steps'], 3108);
    expect(data.containsKey('activeCalories'), isFalse);
    expect(health.requestedInterval, 86400);
  });
  test('denied health access prompts only after an explicit connection',
      () async {
    final health = _Health()..granted = false;
    final service = ActivityService(health: health);
    addTearDown(service.dispose);
    expect(await service.syncHealthData(), isEmpty);
    expect(health.authorizationCalls, 0);
    await expectLater(
        service.syncHealthData(requestPermission: true), throwsStateError);
    expect(health.authorizationCalls, 1);
  });
}
