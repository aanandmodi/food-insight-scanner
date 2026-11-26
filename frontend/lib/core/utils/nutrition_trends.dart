import 'package:intl/intl.dart';

class IndianServingPreset {
  const IndianServingPreset({
    required this.label,
    required this.mealName,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    this.fiber = 0,
    this.sodiumMg = 0,
  });

  final String label;
  final String mealName;
  final String mealType;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double fiber;
  final double sodiumMg;

  Map<String, dynamic> toMealValues() => {
        'name': mealName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'fiber': fiber,
        'sodiumMg': sodiumMg,
        'portionDescription': label,
      };
}

class IndianServingPresets {
  IndianServingPresets._();

  static const List<IndianServingPreset> all = [
    IndianServingPreset(
      label: '1 Roti (35 g)',
      mealName: 'Whole Wheat Roti (1 piece)',
      mealType: 'Lunch',
      calories: 104,
      protein: 3.1,
      carbs: 20.0,
      fat: 1.5,
      sugar: 0.5,
      fiber: 2.8,
      sodiumMg: 120,
    ),
    IndianServingPreset(
      label: '1 Katori Dal',
      mealName: 'Toor / Moong Dal Tadka (1 katori)',
      mealType: 'Lunch',
      calories: 165,
      protein: 9.0,
      carbs: 24.0,
      fat: 3.5,
      sugar: 2.0,
      fiber: 5.5,
      sodiumMg: 360,
    ),
    IndianServingPreset(
      label: '1 Cup Rice',
      mealName: 'Steamed White Rice (1 cup)',
      mealType: 'Lunch',
      calories: 205,
      protein: 4.2,
      carbs: 45.0,
      fat: 0.4,
      sugar: 0.1,
      fiber: 0.6,
      sodiumMg: 2,
    ),
    IndianServingPreset(
      label: '2 Idlis',
      mealName: 'Steamed Idli (2 pieces)',
      mealType: 'Breakfast',
      calories: 130,
      protein: 4.0,
      carbs: 26.0,
      fat: 0.8,
      sugar: 0.5,
      fiber: 1.4,
      sodiumMg: 210,
    ),
    IndianServingPreset(
      label: '1 Plain Dosa',
      mealName: 'Plain Dosa (1 piece)',
      mealType: 'Breakfast',
      calories: 168,
      protein: 3.9,
      carbs: 29.0,
      fat: 3.7,
      sugar: 1.0,
      fiber: 1.8,
      sodiumMg: 280,
    ),
    IndianServingPreset(
      label: '1 Plate Poha',
      mealName: 'Kanda Poha (1 medium plate)',
      mealType: 'Breakfast',
      calories: 250,
      protein: 5.0,
      carbs: 42.0,
      fat: 7.0,
      sugar: 2.0,
      fiber: 2.5,
      sodiumMg: 420,
    ),
    IndianServingPreset(
      label: '1 Bowl Curd',
      mealName: 'Plain Curd / Dahi (1 bowl, 150 g)',
      mealType: 'Snack',
      calories: 98,
      protein: 5.5,
      carbs: 7.0,
      fat: 5.0,
      sugar: 6.5,
      fiber: 0,
      sodiumMg: 68,
    ),
    IndianServingPreset(
      label: '1 Glass Chaas',
      mealName: 'Spiced Buttermilk / Chaas (250 ml)',
      mealType: 'Snack',
      calories: 60,
      protein: 3.2,
      carbs: 5.0,
      fat: 2.5,
      sugar: 4.5,
      fiber: 0,
      sodiumMg: 220,
    ),
  ];
}

class TrendDay {
  const TrendDay({
    required this.dateKey,
    required this.label,
    required this.calories,
    required this.protein,
    required this.sugar,
    required this.carbs,
    required this.fat,
    required this.entriesCount,
  });

  final String dateKey;
  final String label;
  final double calories;
  final double protein;
  final double sugar;
  final double carbs;
  final double fat;
  final int entriesCount;
}

class NutritionTrendSummary {
  const NutritionTrendSummary({
    required this.daysWindow,
    required this.days,
    required this.loggedDays,
    required this.totalEntries,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgSugar,
  });

  final int daysWindow;
  final List<TrendDay> days;
  final int loggedDays;
  final int totalEntries;
  final double? avgCalories;
  final double? avgProtein;
  final double? avgSugar;
}

/// Aggregates logged daily nutrition over a 7- or 30-day window without inventing zero on empty days.
class NutritionTrendCalculator {
  NutritionTrendCalculator._();

  static double _num(Object? v) =>
      v is num && v.isFinite && v >= 0 ? v.toDouble() : 0.0;

  static NutritionTrendSummary compute(
    List<Map<String, dynamic>> allEntries, {
    int daysWindow = 7,
    DateTime? anchorDate,
  }) {
    final normalizedWindow = daysWindow.clamp(1, 90);
    final anchor = anchorDate ?? DateTime.now();
    final today = DateTime(anchor.year, anchor.month, anchor.day);

    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final entry in allEntries) {
      final dateKey = entry['date']?.toString().trim() ?? '';
      if (dateKey.isNotEmpty) {
        byDate.putIfAbsent(dateKey, () => []).add(entry);
      }
    }

    final resultDays = <TrendDay>[];
    var loggedDays = 0;
    var totalEntries = 0;
    double calSum = 0;
    double proteinSum = 0;
    double sugarSum = 0;

    for (var offset = normalizedWindow - 1; offset >= 0; offset--) {
      final d = today.subtract(Duration(days: offset));
      final key = DateFormat('yyyy-MM-dd').format(d);
      final label = normalizedWindow <= 7
          ? DateFormat('E').format(d).substring(0, 1)
          : DateFormat('d').format(d);
      final rows = byDate[key] ?? const [];

      double cals = 0, pro = 0, sug = 0, carb = 0, fat = 0;
      for (final row in rows) {
        cals += _num(row['calories']);
        pro += _num(row['protein']);
        sug += _num(row['sugar']);
        carb += _num(row['carbs']);
        fat += _num(row['fat']);
      }
      if (rows.isNotEmpty) {
        loggedDays++;
        totalEntries += rows.length;
        calSum += cals;
        proteinSum += pro;
        sugarSum += sug;
      }

      resultDays.add(
        TrendDay(
          dateKey: key,
          label: label,
          calories: cals,
          protein: pro,
          sugar: sug,
          carbs: carb,
          fat: fat,
          entriesCount: rows.length,
        ),
      );
    }

    return NutritionTrendSummary(
      daysWindow: normalizedWindow,
      days: resultDays,
      loggedDays: loggedDays,
      totalEntries: totalEntries,
      avgCalories: loggedDays > 0 ? calSum / loggedDays : null,
      avgProtein: loggedDays > 0 ? proteinSum / loggedDays : null,
      avgSugar: loggedDays > 0 ? sugarSum / loggedDays : null,
    );
  }
}
