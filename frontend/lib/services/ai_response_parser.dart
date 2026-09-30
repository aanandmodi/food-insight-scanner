import 'dart:convert';

/// Model output is untrusted input. JSON mode guarantees syntax, not types.
class AiResponseParser {
  static Map<String, dynamic> object(String text) {
    final clean = text
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final value = jsonDecode(clean);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('AI response must be a JSON object');
    }
    return value;
  }

  static double number(dynamic value, String field, {double max = 10000}) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > max) {
      throw FormatException('Invalid $field');
    }
    return parsed;
  }

  static Map<String, dynamic> meal(Map<String, dynamic> data) {
    final name = data['name']?.toString().trim() ?? '';
    if (name.isEmpty) throw const FormatException('Missing meal name');
    return {
      ...data,
      'name': name,
      'calories': number(data['calories'], 'calories').round(),
      for (final key in ['protein', 'carbs', 'fat', 'sugar'])
        key: number(data[key] ?? 0, key, max: 2000),
    };
  }

  static Map<String, dynamic> plan(Map<String, dynamic> data) {
    if (data['meals'] is! List || (data['meals'] as List).isEmpty) {
      throw const FormatException('The meal plan is empty');
    }
    final meals = (data['meals'] as List)
        .map((e) => meal(Map<String, dynamic>.from(e as Map)))
        .toList();
    final types = meals.map((m) => m['type']?.toString().toLowerCase()).toSet();
    if (!types.containsAll(['breakfast', 'lunch', 'dinner', 'snack'])) {
      throw const FormatException('The meal plan is incomplete');
    }
    return {
      ...data,
      'meals': meals,
      'totalCalories':
          meals.fold<num>(0, (sum, m) => sum + (m['calories'] as num)).round(),
      'totalProtein':
          meals.fold<num>(0, (sum, m) => sum + (m['protein'] as num)).round(),
    };
  }
}
