import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:food_insight_scanner/models/user_profile.dart';
import 'package:food_insight_scanner/data/providers/user_profile_provider.dart';
import 'package:food_insight_scanner/services/feature_flag_service.dart';
import 'package:food_insight_scanner/presentation/product_details/product_details.dart';

class _Profile extends ChangeNotifier implements UserProfileProvider {
  @override
  UserProfile get profile => UserProfile(name: 'Test user', allergies: ['Peanut'],
    healthGoals: '', age: 25, activityLevel: 'moderate');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final scale in [1.0, 2.0]) {
    testWidgets('product details preserves back navigation and critical allergy with AI off at $scale', (tester) async {
      tester.view.physicalSize = const Size(360,800); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<UserProfileProvider>(create: (_) => _Profile()),
        ChangeNotifierProvider(create: (_) => FeatureFlagService()),
      ], child: Sizer(builder: (_, __, ___) => MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        onGenerateRoute: (_) => MaterialPageRoute(settings: const RouteSettings(arguments: {
          'barcode':'12345678', 'schemaVersion':2, 'name':'Peanut snack', 'brand':'Fixture',
          'allergens':['peanut'], 'ingredientsText':'peanut, salt', 'ingredients':['peanut','salt'],
          'nutrition':{'energyKcalPer100g':200,'sodiumMgPer100g':750}, 'source':'open_food_facts',
        }), builder: (_) => const ProductDetails()),
      ))));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.scrollUntilVisible(find.text('ALLERGEN CONFLICT'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Avoid this product'), findsOneWidget);
      expect(find.text('Safe for You'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); await tester.pump(const Duration(seconds: 1));
    });
  }
}
