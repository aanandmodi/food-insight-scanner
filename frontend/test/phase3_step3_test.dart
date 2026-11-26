import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/core/utils/nutrition_trends.dart';
import 'package:food_insight_scanner/presentation/diet_log/widgets/diet_trends_card.dart';
import 'package:food_insight_scanner/presentation/diet_log/widgets/meal_entry_dialog.dart';
import 'package:food_insight_scanner/presentation/meal_planner/widgets/planned_meal_card.dart';

void main() {
  group('NutritionTrendCalculator', () {
    test('computes logged-day averages and ignores unlogged gap days', () {
      final anchor = DateTime(2026, 11, 26);
      final entries = [
        {
          'date': '2026-11-26',
          'calories': 600,
          'protein': 30,
          'sugar': 10,
          'carbs': 70,
          'fat': 18,
        },
        {
          'date': '2026-11-26',
          'calories': 400,
          'protein': 20,
          'sugar': 5,
          'carbs': 50,
          'fat': 12,
        },
        {
          'date': '2026-11-24',
          'calories': 1400,
          'protein': 60,
          'sugar': 25,
          'carbs': 160,
          'fat': 40,
        },
        // Outside 7-day window relative to 2026-11-26:
        {
          'date': '2026-11-01',
          'calories': 3000,
          'protein': 120,
          'sugar': 90,
        },
      ];

      final week = NutritionTrendCalculator.compute(
        entries,
        daysWindow: 7,
        anchorDate: anchor,
      );

      expect(week.daysWindow, 7);
      expect(week.days.length, 7);
      expect(week.loggedDays, 2);
      expect(week.totalEntries, 3);
      // Day 1: 1000 kcal, Day 2: 1400 kcal -> average across 2 logged days = 1200.
      expect(week.avgCalories, closeTo(1200.0, 0.01));
      expect(week.avgProtein, closeTo(55.0, 0.01));
      expect(week.avgSugar, closeTo(20.0, 0.01));

      final month = NutritionTrendCalculator.compute(
        entries,
        daysWindow: 30,
        anchorDate: anchor,
      );
      expect(month.daysWindow, 30);
      expect(month.days.length, 30);
      expect(month.loggedDays, 3);
      expect(month.totalEntries, 4);
      expect(month.avgCalories, closeTo((1000 + 1400 + 3000) / 3, 0.01));
    });

    test('returns null averages when no entries fall in the window', () {
      final summary = NutritionTrendCalculator.compute(
        const [],
        daysWindow: 7,
        anchorDate: DateTime(2026, 11, 26),
      );
      expect(summary.loggedDays, 0);
      expect(summary.avgCalories, isNull);
      expect(summary.avgProtein, isNull);
      expect(summary.avgSugar, isNull);
    });
  });

  group('IndianServingPresets', () {
    test('defines Indian household staples with positive calories', () {
      expect(IndianServingPresets.all.length, greaterThanOrEqualTo(6));
      for (final preset in IndianServingPresets.all) {
        final values = preset.toMealValues();
        expect(preset.label, isNotEmpty);
        expect(values['name'], preset.mealName);
        expect((values['calories'] as double), greaterThan(0));
      }
    });
  });

  group('DietTrendsCard widget', () {
    testWidgets('renders averages and switches between 7D and 30D views',
        (tester) async {
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DietTrendsCard(
              calorieGoal: 2000,
              entries: [
                {
                  'date': todayKey,
                  'calories': 950,
                  'protein': 42.5,
                  'sugar': 14.0,
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Nutrition Trends'), findsOneWidget);
      expect(find.textContaining('1 of 7 days logged'), findsOneWidget);
      expect(find.text('Avg kcal: 950'), findsOneWidget);
      expect(find.text('Avg protein: 42.5 g'), findsOneWidget);
      expect(find.text('Avg sugar: 14.0 g'), findsOneWidget);

      await tester.tap(find.text('30D'));
      await tester.pump();
      expect(find.textContaining('1 of 30 days logged'), findsOneWidget);
    });
  });

  group('MealEntryDialog editing and presets', () {
    Future<void> openDialog(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => child,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('edits existing meal and preserves id/date/time/createdAt',
        (tester) async {
      MealValues? savedValues;
      await openDialog(
        tester,
        MealEntryDialog(
          initialMeal: const {
            'id': 'meal-42',
            'date': '2026-11-25',
            'time': '08:30',
            'createdAt': '2026-11-25T03:00:00Z',
            'name': 'Masala Oats',
            'brand': 'Manual Entry',
            'mealType': 'Breakfast',
            'calories': 240,
            'protein': 8.5,
            'carbs': 36,
            'fat': 5,
            'sugar': 3,
            'fiber': 4.5,
            'sodiumMg': 320,
          },
          save: (values) async {
            savedValues = values;
          },
        ),
      );

      expect(find.text('Edit Meal'), findsOneWidget);
      expect(find.text('Update meal'), findsOneWidget);

      // Update calories (TextField.at(1)) and save.
      await tester.enterText(find.byType(TextField).at(1), '310');
      await tester.tap(find.text('Update meal'));
      await tester.pumpAndSettle();

      expect(savedValues, isNotNull);
      expect(savedValues!['id'], 'meal-42');
      expect(savedValues!['date'], '2026-11-25');
      expect(savedValues!['time'], '08:30');
      expect(savedValues!['createdAt'], '2026-11-25T03:00:00Z');
      expect(savedValues!['calories'], 310.0);
      expect(savedValues!['fiber'], 4.5);
      expect(savedValues!['sodiumMg'], 320.0);
    });

    testWidgets('applies Indian household preset chip into fields and saves',
        (tester) async {
      MealValues? savedValues;
      await openDialog(
        tester,
        MealEntryDialog(
          save: (values) async {
            savedValues = values;
          },
        ),
      );

      await tester.tap(find.text('1 Katori Dal'));
      await tester.pump();
      await tester.tap(find.text('Save meal'));
      await tester.pumpAndSettle();

      expect(savedValues, isNotNull);
      expect(savedValues!['name'], 'Toor / Moong Dal Tadka (1 katori)');
      expect(savedValues!['mealType'], 'Lunch');
      expect(savedValues!['calories'], 165.0);
      expect(savedValues!['protein'], 9.0);
    });
  });

  group('PlannedMealCard & ingredient extraction', () {
    test('deduplicates and normalizes meal ingredients', () {
      final list = extractMealIngredients({
        'ingredients': ['Paneer', ' paneer ', '', null, 'Spinach', 'Garlic'],
      });
      expect(list, ['Paneer', 'Spinach', 'Garlic']);
    });

    testWidgets(
        'renders portion, full macros, ingredients and fires action callbacks',
        (tester) async {
      var logged = false;
      var addedIngredients = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlannedMealCard(
                meal: const {
                  'type': 'Lunch',
                  'name': 'Palak Paneer with Roti',
                  'portionDescription': '1 bowl palak paneer + 2 rotis',
                  'calories': 520,
                  'protein': 24,
                  'carbs': 48,
                  'fat': 22,
                  'sugar': 4,
                  'description': 'Balanced high-protein iron-rich lunch.',
                  'ingredients': ['Spinach', 'Paneer', 'Whole Wheat Flour'],
                },
                onLogMeal: () => logged = true,
                onAddIngredients: () => addedIngredients = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Palak Paneer with Roti'), findsOneWidget);
      expect(find.text('1 bowl palak paneer + 2 rotis'), findsOneWidget);
      expect(find.text('520 kcal'), findsOneWidget);
      expect(find.text('24g P'), findsOneWidget);
      expect(find.text('48g Carbs'), findsOneWidget);
      expect(find.text('22g Fat'), findsOneWidget);
      expect(find.text('4g Sugar'), findsOneWidget);
      expect(find.text('Spinach'), findsOneWidget);
      expect(find.text('Paneer'), findsOneWidget);

      await tester.tap(find.text('Log Meal'));
      await tester.tap(find.text('Add Ingredients'));
      expect(logged, isTrue);
      expect(addedIngredients, isTrue);
    });
  });
}
