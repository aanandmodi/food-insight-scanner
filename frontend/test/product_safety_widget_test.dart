import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/safety_alerts_widget.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/nutrition_bars_widget.dart';

void main() {
  for (final scale in [1.0,1.3,1.6,2.0]) {
    testWidgets('critical safety and unknown nutrition remain readable at scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320,800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const Scaffold(body: SingleChildScrollView(child: Column(children: [
          SafetyAlertsWidget(userAllergies:['Peanut'], ingredients:[], dietaryPreference:'', nutritionData:{},productData:{'allergens':['peanut']}),
          NutritionBarsWidget(nutritionData:{}),
        ]))))));
      expect(find.text('ALLERGEN CONFLICT'),findsOneWidget);
      expect(find.text('Avoid this product'),findsOneWidget);
      expect(find.text('Safe for You'),findsNothing);
      expect(find.text('Unavailable'),findsNWidgets(7));
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('missing data is explicitly insufficient', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SafetyAlertsWidget(
      userAllergies:['Milk'],ingredients:[],dietaryPreference:'',nutritionData:{}))));
    expect(find.text('Insufficient data'),findsOneWidget);
    expect(find.text('More product data needed'),findsOneWidget);
  });
}
