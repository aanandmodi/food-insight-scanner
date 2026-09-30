import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/services/ai_response_parser.dart';
import 'package:food_insight_scanner/models/user_profile.dart';

void main() {
  test('rejects prose, incomplete JSON, invalid and negative nutrients', () {
    for (final text in ['Here is a plan', '{"meals":', '[]']) {
      expect(() => AiResponseParser.object(text), throwsFormatException);
    }
    for (final value in [-1, double.nan, double.infinity, 'unknown']) {
      expect(() => AiResponseParser.number(value, 'calories'),
          throwsFormatException);
    }
  });
  test('normalizes numeric strings and recomputes plan totals', () {
    final plan = AiResponseParser.plan({
      'totalCalories': 9999,
      'meals': [
        for (final type in ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
          {
            'type': type,
            'name': 'Dal and roti',
            'calories': '300',
            'protein': '12'
          }
      ]
    });
    expect(plan['totalCalories'], 1200);
    expect(plan['totalProtein'], 48);
    expect(() => AiResponseParser.plan({'meals': []}), throwsFormatException);
  });
  test('profile defaults to India and preserves regional preference', () {
    final profile = UserProfile.fromMap({'name': 'Test', 'region': 'Gujarati'});
    expect(profile.country, 'India');
    expect(
        UserProfile.fromMap(profile.copyWith(name: 'Updated').toMap()).region,
        'Gujarati');

  });
}
