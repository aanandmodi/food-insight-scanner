import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:food_insight_scanner/core/utils/input_validators.dart';
import 'package:food_insight_scanner/data/providers/user_profile_provider.dart';
import 'package:food_insight_scanner/models/user_profile.dart';
import 'package:food_insight_scanner/presentation/home_dashboard/home_dashboard.dart';
import 'package:food_insight_scanner/presentation/home_dashboard/widgets/recent_scans_section.dart';
import 'package:food_insight_scanner/presentation/profile_setup/profile_setup.dart';

class _StubProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  @override
  UserProfile? get profile => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('InputValidators', () {
    test('accepts plus subaddressing and modern long TLDs', () {
      expect(InputValidators.validateEmail('alice+food@gmail.com'), isNull);
      expect(InputValidators.validateEmail('user@nutrition.health'), isNull);
      expect(InputValidators.validateEmail('ops@sub.company.technology'), isNull);
      expect(InputValidators.validateEmail('  a.b+1@domain.co.in '), isNull);
    });

    test('rejects invalid email formats', () {
      expect(InputValidators.validateEmail(''), isNotNull);
      expect(InputValidators.validateEmail('invalid-email'), isNotNull);
      expect(InputValidators.validateEmail('user@localhost'), isNotNull);
      expect(InputValidators.validateEmail('user@.com'), isNotNull);
      expect(InputValidators.validateEmail('user name@gmail.com'), isNotNull);
    });

    test('validates height, weight, and birth date bounds', () {
      expect(InputValidators.validateHeightCm(''), isNull);
      expect(InputValidators.validateHeightCm('170'), isNull);
      expect(InputValidators.validateHeightCm('40'), isNotNull);
      expect(InputValidators.validateHeightCm('300'), isNotNull);
      expect(InputValidators.validateHeightCm('17..0'), isNotNull);

      expect(InputValidators.validateWeightKg(''), isNull);
      expect(InputValidators.validateWeightKg('65.5'), isNull);
      expect(InputValidators.validateWeightKg('10'), isNotNull);
      expect(InputValidators.validateWeightKg('450'), isNotNull);

      final now = DateTime(2026, 11, 25);
      expect(
          InputValidators.validateBirthDate(null, now: now), isNotNull);
      expect(
          InputValidators.validateBirthDate(DateTime(2020, 1, 1), now: now),
          isNotNull);
      expect(
          InputValidators.validateBirthDate(DateTime(1890, 1, 1), now: now),
          isNotNull);
      expect(
          InputValidators.validateBirthDate(DateTime(2000, 1, 1), now: now),
          isNull);
    });
  });

  group('HomeDashboard.determineScanSafety', () {
    final profile = UserProfile(
      name: 'Test',
      allergies: const ['Peanut'],
      dietaryPreferences: const ['vegan'],
      healthGoals: 'general_health',
      age: 26,
      activityLevel: 'moderate',
    );

    test('distinguishes danger, warning, unknown, and safe outcomes', () {
      expect(
        HomeDashboard.determineScanSafety({
          'allergens': ['peanut'],
          'ingredients': ['peanuts'],
        }, profile),
        'danger',
      );

      expect(
        HomeDashboard.determineScanSafety({
          'schemaVersion': 2,
          'ingredients': ['oats'],
          'nutrition': {
            'energyKcalPer100g': 200,
            'proteinGPer100g': 8,
            'sugarGPer100g': 22,
            'fiberGPer100g': 4,
            'sodiumMgPer100g': 100,
          },
        }, profile),
        'warning',
      );

      expect(HomeDashboard.determineScanSafety({}, profile), 'unknown');

      expect(
        HomeDashboard.determineScanSafety({
          'schemaVersion': 2,
          'ingredients': ['oats', 'water'],
          'allergens': const [],
          'nutrition': {
            'energyKcalPer100g': 150,
            'proteinGPer100g': 12,
            'sugarGPer100g': 2,
            'fiberGPer100g': 6,
            'sodiumMgPer100g': 80,
          },
        }, profile),
        'safe',
      );
    });
  });

  group('RecentScansSection navigation', () {
    testWidgets(
        'passes full product map when nutrition exists and barcode string when missing',
        (tester) async {
      Object? pushedArgs;
      await tester.pumpWidget(Sizer(
        builder: (_, __, ___) => MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/product-details') {
              pushedArgs = settings.arguments;
              return MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                      appBar: AppBar(), body: const Text('Details')));
            }
            return null;
          },
          home: Scaffold(
            body: RecentScansSection(
              recentScans: const [
                {
                  'id': '8901234567890',
                  'barcode': '8901234567890',
                  'name': 'Rolled Oats',
                  'brand': 'Brand A',
                  'image': '',
                  'safetyStatus': 'safe',
                  'nutrition': {'energyKcalPer100g': 380},
                },
                {
                  'id': '12345678',
                  'name': 'Summary Only',
                  'image': '',
                  'safetyStatus': 'unknown',
                },
              ],
              onViewAll: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('View details'), findsOneWidget);
      await tester.tap(find.text('Rolled Oats'));
      await tester.pumpAndSettle();
      expect(pushedArgs, isA<Map>());
      expect((pushedArgs as Map)['nutrition'], isNotEmpty);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Summary Only'));
      await tester.pumpAndSettle();
      expect(pushedArgs, '12345678');
    });
  });

  testWidgets('ProfileSetup validates Step 1 before advancing to Step 2',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ChangeNotifierProvider<UserProfileProvider>(
      create: (_) => _StubProfileProvider(),
      child: Sizer(
        builder: (_, __, ___) => const MaterialApp(home: ProfileSetup()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Profile setup · Step 1 of 6'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Profile setup · Step 1 of 6'), findsOneWidget);
    expect(find.text('Please enter your name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'A');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    expect(find.text('Profile setup · Step 1 of 6'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Alice');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Profile setup · Step 2 of 6'), findsOneWidget);
  });
}
