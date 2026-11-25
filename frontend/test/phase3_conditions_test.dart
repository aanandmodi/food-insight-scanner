import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_insight_scanner/models/user_profile.dart';
import 'package:food_insight_scanner/presentation/home_dashboard/home_dashboard.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/safety_alerts_widget.dart';
import 'package:food_insight_scanner/services/cloud_function_service.dart';
import 'package:food_insight_scanner/services/condition_safety_service.dart';
import 'package:food_insight_scanner/services/food_fit_service.dart';
import 'package:food_insight_scanner/services/verified_alternatives_service.dart';

void main() {
  group('ConditionSafetyService & FoodFitService', () {
    test('Diabetes tightens sugar/carb rules and notes missing sugar', () {
      final sugary = FoodFitService.evaluate({
        'schemaVersion': 2,
        'ingredientsText': 'refined wheat flour, sugar, glucose syrup',
        'nutrition': {
          'energyKcalPer100g': 380,
          'sugarGPer100g': 14,
          'carbohydratesGPer100g': 65,
          'fiberGPer100g': 1.5,
          'proteinGPer100g': 6,
          'sodiumMgPer100g': 150,
        },
      }, allergies: const [], conditions: const ['Diabetes (Type 2)']);

      expect(sugary.conditionConflicts, isNotEmpty);
      expect(sugary.conditionConflicts.first, contains('High sugar'));
      expect(sugary.conditionCautions.any((c) => c.contains('carbohydrate')), isTrue);
      expect(sugary.score, lessThanOrEqualTo(25));

      // Privacy guarantee: medical condition names must not be serialized into AI payload.
      expect(sugary.toMap().toString(), isNot(contains('Diabetes')));

      final missingSugar = ConditionSafetyService.evaluate(
        {'ingredientsText': 'oats'},
        conditions: const ['Diabetes (Type 1)'],
      );
      expect(missingSugar.unknowns.any((u) => u.contains('Sugar amount is missing')), isTrue);
    });

    test('Hypertension flags >300mg caution and >=500mg conflict', () {
      final elevated = ConditionSafetyService.evaluate(
        {'ingredientsText': 'lentils, salt'},
        conditions: const ['Hypertension'],
        sodiumMgPer100g: 360,
      );
      expect(elevated.conflicts, isEmpty);
      expect(elevated.cautions.any((c) => c.contains('Elevated sodium')), isTrue);

      final high = ConditionSafetyService.evaluate(
        {'ingredientsText': 'chips, salt'},
        conditions: const ['Hypertension'],
        sodiumMgPer100g: 620,
      );
      expect(high.conflicts.any((c) => c.contains('High sodium')), isTrue);
    });

    test('Celiac Disease escalates gluten to critical conflict and withholds numeric score', () {
      final wheat = FoodFitService.evaluate({
        'schemaVersion': 2,
        'ingredientsText': 'whole wheat flour, water, salt',
        'nutrition': {
          'energyKcalPer100g': 240,
          'sugarGPer100g': 2,
          'proteinGPer100g': 9,
          'fiberGPer100g': 7,
          'sodiumMgPer100g': 200,
        },
      }, allergies: const [], conditions: const ['Celiac Disease']);

      expect(wheat.hasCriticalConditionConflict, isTrue);
      expect(wheat.score, isNull);
      expect(wheat.conditionConflicts.first, contains('Celiac Disease'));
      expect(wheat.toMap()['scoreStatus'], 'withheld_due_to_dietary_restriction');
    });

    test('Lactose Intolerance flags dairy unless explicitly lactose-free', () {
      final wheyDrink = ConditionSafetyService.evaluate(
        {'ingredientsText': 'water, whey protein concentrate, cocoa'},
        conditions: const ['Lactose Intolerance'],
      );
      expect(wheyDrink.conflicts, isNotEmpty);

      final lactoseFree = ConditionSafetyService.evaluate(
        {
          'name': 'Lactose Free Curd',
          'ingredientsText': 'lactose-free milk, live cultures',
        },
        conditions: const ['Lactose Intolerance'],
      );
      expect(lactoseFree.conflicts, isEmpty);
    });

    test('Kidney Disease flags phosphate INS 451 / potassium INS 508 additives', () {
      final renal = ConditionSafetyService.evaluate(
        {
          'ingredientsText': 'noodles, sodium tripolyphosphate (INS 451), salt',
        },
        conditions: const ['Kidney Disease'],
        sodiumMgPer100g: 420,
      );
      expect(renal.conflicts.length, 2);
      expect(renal.conflicts.any((c) => c.contains('Phosphate or potassium')), isTrue);
    });
  });

  group('HomeDashboard, Alternatives, Plan Safety & SafetyAlertsWidget', () {
    test('HomeDashboard.determineScanSafety surfaces danger and warning for saved conditions', () {
      final glutenSnack = {
        'schemaVersion': 2,
        'ingredientsText': 'maida, salt',
        'nutrition': {
          'energyKcalPer100g': 200,
          'sugarGPer100g': 1,
          'proteinGPer100g': 6,
          'fiberGPer100g': 2,
          'sodiumMgPer100g': 120,
        },
      };
      final celiac = UserProfile(
        name: 'Asha',
        allergies: const [],
        diseases: const ['Celiac Disease'],
        healthGoals: '',
        age: 28,
        activityLevel: 'moderate',
      );
      expect(HomeDashboard.determineScanSafety(glutenSnack, celiac), 'danger');

      final moderateSodium = {
        'schemaVersion': 2,
        'ingredientsText': 'roasted makhana, salt',
        'nutrition': {
          'energyKcalPer100g': 180,
          'sugarGPer100g': 1,
          'proteinGPer100g': 8,
          'fiberGPer100g': 4,
          'sodiumMgPer100g': 380,
        },
      };
      final hypertension = UserProfile(
        name: 'Asha',
        allergies: const [],
        diseases: const ['Hypertension'],
        healthGoals: '',
        age: 50,
        activityLevel: 'light',
      );
      expect(
        HomeDashboard.determineScanSafety(moderateSodium, hypertension),
        'warning',
      );
    });

    test('VerifiedAlternativesService filters candidates conflicting with diseases', () {
      final current = {
        'barcode': '11111111',
        'schemaVersion': 2,
        'name': 'Salted Crackers',
        'allergens': const [],
        'ingredientsText': 'wheat flour, palm oil, salt',
        'nutrition': {
          'energyKcalPer100g': 430,
          'sugarGPer100g': 14,
          'sodiumMgPer100g': 650,
          'proteinGPer100g': 6,
          'fiberGPer100g': 2,
        },
      };
      final candidates = [
        {
          'barcode': '22222222',
          'source': 'open_food_facts',
          'name': 'Honey Wheat Cookies',
          'dataCompleteness': 0.9,
          'allergens': const ['milk'],
          'ingredientsText': 'whole wheat flour, honey, salt',
          'nutrition': {
            'energyKcalPer100g': 350,
            'sugarGPer100g': 12,
            'sodiumMgPer100g': 200,
            'proteinGPer100g': 8,
            'fiberGPer100g': 5,
          },
        },
        {
          'barcode': '33333333',
          'source': 'open_food_facts',
          'name': 'Millet Rice Crisp',
          'dataCompleteness': 0.9,
          'allergens': const [],
          'ingredientsText': 'brown rice, jowar millet, spices',
          'nutrition': {
            'energyKcalPer100g': 340,
            'sugarGPer100g': 1,
            'sodiumMgPer100g': 120,
            'proteinGPer100g': 10,
            'fiberGPer100g': 8,
          },
        },
      ];
      final ranked = VerifiedAlternativesService.rank(current, candidates, {
        'allergies': const <String>[],
        'diseases': const ['Celiac Disease'],
      });
      expect(ranked.length, 1);
      expect(ranked.first['product']['barcode'], '33333333');
    });

    test('validatePlanSafety blocks wheat meals when user has Celiac Disease', () {
      final unsafePlan = {
        'summary': 'Balanced plan',
        'meals': [
          {
            'type': 'Breakfast',
            'name': '2 Whole Wheat Paratha',
            'description': 'Served with curd',
            'ingredients': ['whole wheat flour', 'oil', 'salt'],
          },
        ],
      };
      expect(
        () => CloudFunctionService.validatePlanSafety(unsafePlan, {
          'allergies': const <String>[],
          'diseases': const ['Celiac Disease'],
        }),
        throwsA(isA<AiRequestException>()),
      );
    });

    testWidgets('SafetyAlertsWidget renders CONDITION CONFLICT and medical advice disclaimer',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SafetyAlertsWidget(
                userAllergies: [],
                userConditions: ['Celiac Disease'],
                ingredients: ['wheat flour', 'salt'],
                dietaryPreference: '',
                nutritionData: {
                  'energyKcalPer100g': 240,
                  'sugarGPer100g': 2,
                  'proteinGPer100g': 8,
                  'fiberGPer100g': 4,
                  'sodiumMgPer100g': 180,
                },
                productData: {'schemaVersion': 2},
              ),
            ),
          ),
        ),
      );

      expect(find.text('CONDITION CONFLICT'), findsOneWidget);
      expect(find.text('Avoid this product'), findsOneWidget);
      expect(find.textContaining('Celiac Disease'), findsOneWidget);
      expect(find.textContaining('healthcare professional'), findsOneWidget);
    });
  });
}
