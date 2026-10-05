import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/services/food_additive_service.dart';

void main() {
  test('INS and E forms normalize and deduplicate without losing variants', () {
    expect(
        FoodAdditiveService.extract('INS 211, INS-211, INS(211), E211, E 211'),
        ['211']);
    expect(FoodAdditiveService.extract('INS 211(i), INS 330, en:e415'),
        ['211(i)', '330', '415']);
  });
  test('partial labels, plain numbers and unrelated text are not identifiers',
      () {
    for (final input in [
      '211',
      'INS',
      'INS 21',
      'INS(211',
      'INS 211(i',
      'INS 21100',
      'vitamine211',
      'rice'
    ]) {
      expect(FoodAdditiveService.extract(input), isEmpty, reason: input);
    }
  });
  test('OFF lecithin subtype resolves without duplicating its parent tag', () {
    final service = FoodAdditiveService.fromMap(jsonDecode(
        File('assets/data/food_additives_v1.json').readAsStringSync()));
    final rows = service.inspect({
      'additives': ['en:e322', 'en:e322i']
    });
    expect(rows.length, 1);
    expect(rows.single['ins'], '322(i)');
    expect(rows.single['known'], true);
    expect(
        service.inspect({
          'additives': ['en:e322']
        }).single['known'],
        false);
  });
  test('local data only resolves exact curated identities', () {
    final service = FoodAdditiveService.fromMap(jsonDecode(
        File('assets/data/food_additives_v1.json').readAsStringSync()));
    final rows = service.inspect({
      'ingredientsText': 'INS 211, INS 211(i), INS 999, E330, INS 322(i)',
      'additives': ['en:e415', 'en:e211']
    });
    expect(rows.length, 6);
    expect(rows.first['name'], 'Sodium benzoate');
    expect(rows[1]['known'], false);
    expect(rows[2]['known'], false);
    for (final row in rows.where((r) => r['known'] == true)) {
      expect(row['sources'], isNotEmpty);
      expect(row.containsKey('risk'), false);
    }
  });
}
