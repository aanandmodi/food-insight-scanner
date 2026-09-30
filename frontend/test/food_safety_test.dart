import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/services/allergen_safety_service.dart';
import 'package:food_insight_scanner/services/food_fit_service.dart';
import 'package:food_insight_scanner/services/product_facts_adapter.dart';
import 'package:food_insight_scanner/services/product_portion_service.dart';

void main() {
  test('structured allergens and synonyms override favorable nutrition', () {
    for (final pair in [
      ('whey', 'Dairy'),
      ('groundnut', 'Peanut'),
      ('cashew', 'Nuts'),
      ('barley', 'Gluten'),
      ('soya', 'Soy')
    ]) {
      final result = AllergenSafetyService.evaluate({
        'allergens': [pair.$1]
      }, [
        pair.$2
      ]);
      expect(result.status, AllergenStatus.confirmedConflict);
    }
    final fit = FoodFitService.evaluate({
      'allergens': ['milk'],
      'nutrition': {'protein': 30, 'sugar': 0, 'calories': 100}
    }, allergies: [
      'Dairy'
    ]);
    expect(fit.hasCriticalAllergenConflict, isTrue);
    expect(fit.score, isNull);
  });
  test('trace conflicts are distinct from declared and missing data', () {
    expect(
        AllergenSafetyService.evaluate({
          'traces': ['en:peanuts']
        }, [
          'Peanut'
        ]).status,
        AllergenStatus.possibleTrace);
    expect(
        AllergenSafetyService.evaluate(
                {'ingredientsText': 'Rice. May contain peanuts'}, ['Peanut'])
            .status,
        AllergenStatus.possibleTrace);
    expect(AllergenSafetyService.evaluate({}, ['Peanut']).status,
        AllergenStatus.insufficientData);
    expect(
        AllergenSafetyService.evaluate({
          'ingredients': ['rice']
        }, [
          'Peanut'
        ]).status,
        AllergenStatus.noDetectedConflict);
    expect(
        AllergenSafetyService.evaluate({
          'ingredients': ['eggplant']
        }, [
          'Eggs'
        ]).status,
        AllergenStatus.noDetectedConflict);
  });
  test('multiple allergies and case differences retain all conflicts', () {
    final result = AllergenSafetyService.evaluate({
      'allergens': ['MILK', 'en:soybeans']
    }, [
      'Dairy',
      'Soy'
    ]);
    expect(result.confirmed, ['Dairy', 'Soy']);
  });
  test(
      'legacy sodium is unknown, canonical sodium survives cache and portion conversion',
      () {
    final legacy = ProductFactsAdapter.adapt({
      'nutrition': {'sodium': 0.7}
    });
    expect((legacy['nutrition'] as Map)['sodium'], isNull);
    final invalid = ProductFactsAdapter.adapt({
      'schemaVersion': 2,
      'nutrition': {'sugarGPer100g': 150, 'sodiumMgPer100g': 120000}
    });
    expect((invalid['nutrition'] as Map)['sugarGPer100g'], isNull);
    expect((invalid['nutrition'] as Map)['sodiumMgPer100g'], isNull);
    final current = ProductFactsAdapter.adapt({
      'schemaVersion': 2,
      'nutrition': {
        'sodiumMgPer100g': 700,
        'energyKcalPer100g': 200,
        'proteinGPer100g': 10
      }
    });
    final portion = ProductPortionService.nutrients(current, 30);
    expect(portion['sodiumMg'], 210);
    expect(portion['calories'], 60);
    expect(portion['protein'], 3);
    expect(portion['nutritionIncomplete'], isTrue);
    expect(() => ProductPortionService.nutrients(current, -1),
        throwsFormatException);
  });
  test('incomplete products never receive a numeric score', () {
    expect(FoodFitService.evaluate({}, allergies: []).score, isNull);
    expect(FoodFitService.evaluate({}, allergies: []).confidence,
        FoodFitConfidence.insufficientData);
  });
  test('nutrition, diet and goals affect fit deterministically', () {
    final base = {
      'schemaVersion': 2,
      'ingredients': ['rice'],
      'nutrition': {
        'calories': 450,
        'protein': 15,
        'sugar': 20,
        'fiber': 7,
        'sodiumMgPer100g': 750
      }
    };
    final fit = FoodFitService.evaluate(base, allergies: []);
    expect(fit.cautions.any((s) => s.contains('High sodium')), isTrue);
    expect(fit.cautions.any((s) => s.contains('High sugar')), isTrue);
    expect(fit.positives.any((s) => s.contains('protein')), isTrue);
    final loss =
        FoodFitService.evaluate(base, allergies: [], healthGoal: 'Weight loss');
    expect(loss.score, lessThan(fit.score!));
    final vegan = FoodFitService.evaluate({
      ...base,
      'ingredients': ['milk']
    }, allergies: [], dietaryPreference: 'Vegan');
    expect(vegan.conflicts, isNotEmpty);
    expect(vegan.score, lessThanOrEqualTo(25));
    final vegetarian = FoodFitService.evaluate({
      ...base,
      'ingredients': ['chicken']
    }, allergies: [], dietaryPreference: 'Vegetarian');
    expect(vegetarian.conflicts, isNotEmpty);
    final omnivore = FoodFitService.evaluate({
      ...base,
      'ingredients': ['chicken']
    }, allergies: [], dietaryPreference: 'Non Vegetarian');
    expect(omnivore.conflicts, isEmpty);
    final trace = FoodFitService.evaluate({
      ...base,
      'traces': ['milk']
    }, allergies: [
      'Milk'
    ], healthGoal: 'High protein');
    expect(trace.score, lessThanOrEqualTo(45));
  });
}
