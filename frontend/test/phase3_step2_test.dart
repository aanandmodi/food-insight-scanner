import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import 'package:food_insight_scanner/presentation/barcode_scanner/widgets/error_message_widget.dart';
import 'package:food_insight_scanner/presentation/barcode_scanner/widgets/manual_product_dialog.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/action_bar_widget.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/portion_picker_dialog.dart';
import 'package:food_insight_scanner/services/food_additive_service.dart';
import 'package:food_insight_scanner/services/product_portion_service.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ProductPortionService g / ml / kg & serving presets', () {
    final product = {
      'servingSize': '250 ml',
      'nutrition': {
        'calories': 60,
        'protein': 3,
        'sugar': 5,
        'fat': 3,
        'carbs': 5,
        'fiber': 0,
        'sodiumMgPer100g': 45,
      },
    };

    test('parses serving sizes and calculates g, ml, and kg portions cleanly',
        () {
      final parsedMl = ProductPortionService.parseServingSize('250 ml');
      expect(parsedMl, isNotNull);
      expect(parsedMl!.unit, PortionUnit.ml);
      expect(parsedMl.amount, 250);

      final parsedPack = ProductPortionService.parseServingSize('1 pack (45g)');
      expect(parsedPack, isNotNull);
      expect(parsedPack!.unit, PortionUnit.g);
      expect(parsedPack.amount, 45);

      final parsedKg = ProductPortionService.parseServingSize('0.5 kg');
      expect(parsedKg, isNotNull);
      expect(parsedKg!.unit, PortionUnit.kg);
      expect(parsedKg.amount, 0.5);

      final scaledMl = ProductPortionService.nutrientsForAmount(
        product,
        250,
        PortionUnit.ml,
      );
      expect(scaledMl['calories'], 150);
      expect(scaledMl['portionGrams'], 250);
      expect(scaledMl['serving'], '250 ml');
      expect(scaledMl['portionUnit'], 'ml');

      final scaledKg = ProductPortionService.nutrientsForAmount(
        product,
        0.5,
        PortionUnit.kg,
      );
      expect(scaledKg['calories'], 300);
      expect(scaledKg['portionGrams'], 500);
      expect(scaledKg['serving'], '0.5 kg');
      expect(scaledKg['portionUnit'], 'kg');

      expect(
        () => ProductPortionService.nutrientsForAmount(
          product,
          2.5,
          PortionUnit.kg,
        ),
        throwsFormatException,
      );
    });

    testWidgets(
        'PortionPickerDialog allows switching between g, ml, and kg presets',
        (tester) async {
      Map<String, dynamic>? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await showPortionPickerDialog(
                    context,
                    productData: product,
                  );
                },
                child: const Text('Pick Portion'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Portion'));
      await tester.pumpAndSettle();

      // Starts on ml from '250 ml' serving size.
      expect(find.text('1 serving (250 ml)'), findsOneWidget);

      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0.5 kg'));
      await tester.pumpAndSettle();

      expect(find.textContaining('300 kcal'), findsOneWidget);
      await tester.tap(find.text('Add meal'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!['calories'], 300);
      expect(picked!['serving'], '0.5 kg');
      expect(picked!['portionGrams'], 500);
    });
  });

  group('ActionBarWidget Shopping List integration', () {
    testWidgets('invokes shopping list callback cleanly alongside diet log',
        (tester) async {
      var dietTapped = 0;
      var shoppingTapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarWidget(
              productData: const {'barcode': '8901234567890'},
              onAddToDietLog: () => dietTapped++,
              onAddToShoppingList: () => shoppingTapped++,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Add to shopping list'));
      await tester.tap(find.text('Add to diet log'));
      expect(shoppingTapped, 1);
      expect(dietTapped, 1);
    });
  });

  group('Expanded INS food additive glossary', () {
    test('includes >=80 Codex/FSSAI additives without risk verdicts or broken negative fixtures',
        () {
      final raw = jsonDecode(
        File('assets/data/food_additives_v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final list = raw['additives'] as List;
      expect(list.length, greaterThanOrEqualTo(80));

      final service = FoodAdditiveService.fromMap(raw);
      final rows = service.inspect({
        'ingredientsText':
            'sugar, acidity regulator (INS 330), flavour enhancer (INS 621), emulsifier (INS 322(i)), sweetener (E955), unknown (INS 999)',
      });
      expect(rows.any((r) => r['ins'] == '621' && r['known'] == true), isTrue);
      expect(rows.any((r) => r['ins'] == '955' && r['known'] == true), isTrue);
      expect(
          rows.any((r) => r['ins'] == '322(i)' && r['known'] == true), isTrue);
      expect(rows.any((r) => r['ins'] == '999' && r['known'] == false), isTrue);
      for (final item in list.cast<Map<String, dynamic>>()) {
        expect(item['sources'], isNotEmpty);
        expect(item.containsKey('risk'), isFalse);
      }
    });
  });

  group('Missing product recovery UI', () {
    testWidgets('ErrorMessageWidget exposes secondary recovery button safely',
        (tester) async {
      var secondaryCalls = 0;
      await tester.pumpWidget(
        Sizer(
          builder: (_, __, ___) => MaterialApp(
            home: Scaffold(
              body: ErrorMessageWidget(
                title: 'Product Not Found',
                message: 'Barcode missing from Open Food Facts.',
                actionText: 'Try Again',
                onAction: () {},
                secondaryActionText: 'Add From Package Label',
                onSecondaryAction: () => secondaryCalls++,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add From Package Label'));
      expect(secondaryCalls, 1);
    });

    testWidgets(
        'ManualProductDialog builds schemaVersion 2 product preserving unknown blanks',
        (tester) async {
      Map<String, dynamic>? created;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  created = await showManualProductDialog(
                    context,
                    barcode: '8901234500001',
                  );
                },
                child: const Text('Open Manual Label'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Manual Label'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Product Name *'),
          'Homemade Bajra Bhakri Mix');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Energy (kcal)'), '360');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Ingredients'),
          'pearl millet, spices');
      await tester.tap(find.text('Save & Analyze'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!['barcode'], '8901234500001');
      expect(created!['source'], 'user_label');
      expect(created!['schemaVersion'], 2);
      expect((created!['nutrition'] as Map)['calories'], 360);
      expect((created!['nutrition'] as Map)['sugar'], isNull);
    });
  });
}
