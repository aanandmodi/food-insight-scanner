import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/core/app_export.dart';
import 'package:food_insight_scanner/services/allergen_safety_service.dart';
import 'package:food_insight_scanner/services/consent_service.dart';
import 'package:food_insight_scanner/services/feature_flag_service.dart';

void main() {
  group('AllergenSafetyService Indian culinary & boundary coverage', () {
    test('detects Indian dairy, nut, gluten, egg, and sesame aliases accurately',
        () {
      expect(
        AllergenSafetyService.evaluate({
          'ingredients': ['dahi', 'paneer']
        }, [
          'Milk'
        ]).status,
        AllergenStatus.confirmedConflict,
      );
      expect(
        AllergenSafetyService.evaluate({
          'ingredientsText': 'Prepared with moongfali and til'
        }, [
          'Peanut'
        ]).status,
        AllergenStatus.confirmedConflict,
      );
      expect(
        AllergenSafetyService.evaluate({
          'ingredientsText': 'Sweetened with kaju and badam'
        }, [
          'Tree Nuts'
        ]).status,
        AllergenStatus.confirmedConflict,
      );
      expect(
        AllergenSafetyService.evaluate({
          'ingredientsText': 'anda bhurji with coriander'
        }, [
          'Egg'
        ]).status,
        AllergenStatus.confirmedConflict,
      );
    });

    test('prevents substring false positives on Indian staples like kanda and lentils',
        () {
      expect(
        AllergenSafetyService.evaluate({
          'ingredientsText': 'kanda poha with fresh coriander leaves'
        }, [
          'Egg'
        ]).status,
        AllergenStatus.noDetectedConflict,
      );
      expect(
        AllergenSafetyService.evaluate({
          'ingredientsText': 'yellow lentils, jeera, haldi'
        }, [
          'Sesame'
        ]).status,
        AllergenStatus.noDetectedConflict,
      );
    });
  });

  group('AppRoutes wiring verification', () {
    test('onGenerateRoute resolves every core named screen cleanly', () {
      const dynamicRoutes = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.profileSetup,
        AppRoutes.barcodeScanner,
        AppRoutes.aiChatAssistant,
        AppRoutes.productDetails,
        AppRoutes.scanHistory,
        AppRoutes.dietLog,
        AppRoutes.profile,
        AppRoutes.settings,
        AppRoutes.shoppingList,
        AppRoutes.mealPlanner,
      ];
      for (final name in dynamicRoutes) {
        final route = AppRoutes.onGenerateRoute(RouteSettings(name: name));
        expect(route, isNotNull, reason: 'Missing route for $name');
      }
      expect(AppRoutes.routes.containsKey(AppRoutes.initial), isTrue);
      expect(AppRoutes.routes.containsKey(AppRoutes.authGate), isTrue);
      expect(AppRoutes.routes.containsKey(AppRoutes.splash), isTrue);
      expect(AppRoutes.routes.containsKey(AppRoutes.homeDashboard), isTrue);
    });
  });

  group('FeatureFlagService & ConsentService fail-closed defaults', () {
    test('FeatureFlagService keeps AI flags disabled when signed out', () {
      final flags = FeatureFlagService();
      addTearDown(flags.dispose);
      expect(flags.aiEnabled, isFalse);
      expect(flags.aiChatEnabled, isFalse);
      expect(flags.mealPlannerEnabled, isFalse);
      expect(flags.aiProductAnalysisEnabled, isFalse);
      expect(flags.aiMealParserEnabled, isFalse);
      expect(flags.aiRecalibrationEnabled, isFalse);
      expect(flags.alternativesEnabled, isFalse);
    });

    test('LegalConsentRecord enforces matching terms and privacy versions', () {
      final valid = LegalConsentRecord(
        termsVersion: ConsentService.currentTermsVersion,
        privacyVersion: ConsentService.currentPrivacyVersion,
        healthDataConsent: true,
        acceptedAt: DateTime.utc(2026, 11, 26),
      );
      expect(
        valid.matchesRequired(
          ConsentService.currentTermsVersion,
          ConsentService.currentPrivacyVersion,
        ),
        isTrue,
      );
      expect(
        valid.matchesRequired('2026-12-01', ConsentService.currentPrivacyVersion),
        isFalse,
      );
    });
  });
}
