import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/services/verified_alternatives_service.dart';

void main() {
  Map<String, dynamic> product(String code, double sugar,
          {String ingredients = 'oats', double completeness = 1}) =>
      {
        'barcode': code,
        'name': 'Catalog oats',
        'source': 'open_food_facts',
        'schemaVersion': 2,
        'dataCompleteness': completeness,
        'ingredientsText': ingredients,
        'allergens': <String>[],
        'nutrition': {
          'energyKcalPer100g': 350,
          'proteinGPer100g': 12,
          'sugarGPer100g': sugar,
          'sodiumMgPer100g': 100,
          'fiberGPer100g': 8
        },
      };
  test('only complete real records with better known values survive', () {
    final current = product('12345678', 20);
    final good = product('12345679', 5);
    final result = VerifiedAlternativesService.rank(current, [
      good,
      product('12345680', 3, completeness: 0.3),
      product('12345681', 1, ingredients: 'peanut oats'),
      {...good, 'barcode': 'made-up'},
      {...good, 'source': 'ai'}
    ], {
      'allergies': ['peanut']
    });
    expect(result.length, 1);
    expect(result.single['product'], same(good));
    expect((result.single['product'] as Map).containsKey('price'), false);
    expect((result.single['product'] as Map).containsKey('image'), false);
  });
  test('unknown dietary compatibility is not promoted', () {
    expect(
        VerifiedAlternativesService.rank(product('12345678', 20), [
          product('12345679', 5)
        ], {
          'dietaryPreferences': ['vegan']
        }),
        isEmpty);
  });
}
