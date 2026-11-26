import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/services/ai_context_builder.dart';

void main() {
  final now = DateTime(2026, 9, 30);
  final profile = <String, dynamic>{
    'age': 24,
    'weightKg': 64,
    'heightCm': 183,
    'healthGoals': 'Build Muscle',
    'allergies': ['peanut'],
    'dietaryPreferences': ['vegan'],
    'email': 'secret-email',
    'uid': 'secret-uid',
    'password': 'secret-password',
    'customCaloriesGoal': 2500,
    'customProteinGoal': 128
  };
  test('personalized bounded context excludes identity', () {
    final a = AIContextBuilder.build(
        task: 'chat',
        userProfile: profile,
        now: now,
        logs: List.generate(
            20,
            (i) => {
                  'date': '2026-09-30',
                  'name': 'Dal',
                  'protein': 5,
                  'calories': 100,
                  'uid': 'secret-uid'
                }));
    final b = AIContextBuilder.build(
        task: 'chat',
        userProfile: {
          ...profile,
          'healthGoals': 'Lose Weight',
          'allergies': <String>[],
          'dietaryPreferences': ['non-vegetarian']
        },
        now: now);
    expect(a['profile'], isNot(b['profile']));
    expect(jsonEncode(a), isNot(contains('secret')));
    expect((a['recentMeals'] as List).length, 8);
    expect(a['today']['remaining']['protein'], 28);
    expect(a['sevenDay']['daysLogged'], 1);
  });
  test('unknown intake is never invented zero and partial macros remain null',
      () {
    final empty =
        AIContextBuilder.build(task: 'chat', userProfile: {}, now: now);
    expect(empty['today']['protein'], null);
    expect(empty['targets'], isEmpty);
    final partial = AIContextBuilder.totals([
      {'protein': 5},
      {'protein': null}
    ]);
    expect(partial['protein'], null);
    expect(
        AIContextBuilder.totals([
          {'protein': 0}
        ])['protein'],
        0);
  });
  test('task minimization and stale activity suppression', () {
    final meal =
        AIContextBuilder.build(task: 'meal', userProfile: profile, now: now);
    expect(meal.keys, ['profile']);
    expect(meal['profile']['age'], null);
    final analysis = AIContextBuilder.build(
        task: 'analysis',
        userProfile: profile,
        now: now,
        activity: {'source': 'none', 'steps': 9000});
    expect(analysis.containsKey('recentMeals'), false);
    expect(analysis.containsKey('activity'), false);
    final withBarcode = AIContextBuilder.productFacts({
      'barcode': '8901234567890',
      'name': 'Masala Oats',
      'nutrition': {'calories': 380},
    });
    expect(withBarcode['barcode'], '8901234567890');
  });
}
