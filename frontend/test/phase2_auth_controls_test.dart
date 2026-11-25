import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import 'package:food_insight_scanner/core/utils/input_validators.dart';
import 'package:food_insight_scanner/presentation/auth/auth_dialogs.dart';
import 'package:food_insight_scanner/services/auth_service.dart';
import 'package:food_insight_scanner/services/data_export_service.dart';
import 'package:food_insight_scanner/widgets/email_verification_banner.dart';
import 'package:food_insight_scanner/widgets/password_strength_meter.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Strong password policy & PasswordStrengthMeter', () {
    test('rejects weak passwords, common words, email overlap, and reuse', () {
      expect(InputValidators.validateStrongPassword(''), isNotNull);
      expect(InputValidators.validateStrongPassword('Short1!'), isNotNull);
      expect(InputValidators.validateStrongPassword('alllower1!'), isNotNull);
      expect(InputValidators.validateStrongPassword('ALLUPPER1!'), isNotNull);
      expect(InputValidators.validateStrongPassword('NoDigits!!'), isNotNull);
      expect(InputValidators.validateStrongPassword('NoSpecial1'), isNotNull);
      expect(
        InputValidators.validateStrongPassword('Password123!'),
        contains('easy-to-guess'),
      );
      expect(
        InputValidators.validateStrongPassword(
          'Aanand#9876',
          email: 'aanand@example.com',
        ),
        contains('email'),
      );
      expect(
        InputValidators.validateStrongPassword(
          'SafePass!2026',
          disallowMatch: 'SafePass!2026',
        ),
        contains('differ'),
      );
      expect(
        InputValidators.validateStrongPassword('T@styScanner2026'),
        isNull,
      );
    });

    test('evaluatePasswordStrength rates weak vs strong progressively', () {
      final weak = InputValidators.evaluatePasswordStrength('abc');
      expect(weak.level, PasswordStrengthLevel.weak);
      expect(weak.hasMinLength, isFalse);

      final strong =
          InputValidators.evaluatePasswordStrength('M@ngoLassi2026!');
      expect(strong.level, PasswordStrengthLevel.strong);
      expect(strong.hasMinLength, isTrue);
      expect(strong.hasUppercase, isTrue);
      expect(strong.hasLowercase, isTrue);
      expect(strong.hasDigit, isTrue);
      expect(strong.hasSpecial, isTrue);
    });

    testWidgets('PasswordStrengthMeter displays rule badges', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: PasswordStrengthMeter(password: 'M@ngoLassi2026!'),
            ),
          ),
        ),
      );
      expect(find.text('Strong'), findsOneWidget);
      expect(find.text('8+ chars'), findsOneWidget);
      expect(find.text('A-Z'), findsOneWidget);
      expect(find.text('Symbol'), findsOneWidget);
    });
  });

  group('Auth dialogs (Forgot Password & Change Password)', () {
    testWidgets('ForgotPasswordDialog masks user-not-found (non-enumerating)',
        (tester) async {
      var submittedEmail = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showForgotPasswordDialog(
                  context,
                  initialEmail: 'nobody+food@example.health',
                  onSendResetOverride: (email) async {
                    submittedEmail = email;
                    throw AuthException(
                      code: 'user-not-found',
                      message: 'No account found.',
                    );
                  },
                ),
                child: const Text('Open Reset'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Reset'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(submittedEmail, 'nobody+food@example.health');
      expect(
        find.textContaining('If an account exists for nobody+food@example.health'),
        findsOneWidget,
      );
    });

    testWidgets(
        'ChangePasswordDialog enforces strong rules and submits validated passwords',
        (tester) async {
      String? capturedCurrent;
      String? capturedNext;
      bool result = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showChangePasswordDialog(
                    context,
                    emailOverride: 'chef@foodinsight.app',
                    onChangePasswordOverride: (cur, next) async {
                      capturedCurrent = cur;
                      capturedNext = next;
                    },
                  );
                },
                child: const Text('Open Change'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Change'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Current Password'), 'OldP@ss1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'), 'weak');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'), 'weak');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(capturedCurrent, isNull);
      expect(
          find.text('Password must be at least 8 characters'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'Fr3sh!Avocado9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          'Fr3sh!Avocado9');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(capturedCurrent, 'OldP@ss1');
      expect(capturedNext, 'Fr3sh!Avocado9');
      expect(result, isTrue);
    });
  });

  group('EmailVerificationBanner', () {
    testWidgets('triggers resend cooldown and refresh callback',
        (tester) async {
      var resends = 0;
      var refreshes = 0;
      var verifiedCallback = false;

      await tester.pumpWidget(
        Sizer(
          builder: (_, __, ___) => MaterialApp(
            home: Scaffold(
              body: EmailVerificationBanner(
                visibleOverride: true,
                emailOverride: 'user@example.com',
                onResendOverride: () async => resends++,
                onRefreshOverride: () async {
                  refreshes++;
                  return true;
                },
                onVerified: () => verifiedCallback = true,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('user@example.com'), findsOneWidget);
      await tester.tap(find.text('Resend email'));
      await tester.pumpAndSettle();
      expect(resends, 1);
      expect(find.textContaining('Resend ('), findsOneWidget);

      await tester.tap(find.text("I've Verified"));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(verifiedCallback, isTrue);
    });
  });

  group('DataExportService & Export Dialog', () {
    test('builds valid JSON and neutralizes CSV formula injection', () {
      final jsonStr = DataExportService.buildJsonExport(
        account: {'uid': 'u1', 'email': 'u1@example.com'},
        profile: {'name': 'Asha', 'allergies': ['peanut']},
        consent: {'termsVersion': '2026-09-30'},
        dietEntries: [
          {
            'date': '2026-11-25',
            'time': '08:30',
            'mealType': 'Breakfast',
            'name': '=CMD("calc"), Oats',
            'calories': 320,
            'protein': 12,
            'carbs': 50,
            'fat': 6,
            'sugar': 4,
            'portion': '1 bowl',
            'source': 'manual',
          }
        ],
        scans: [
          {
            'scannedAt': '2026-11-25T07:00:00Z',
            'barcode': '8901234567890',
            'name': '+Danger, Bar',
            'brand': 'Co',
            'safetyStatus': 'safe',
            'nutrition': {'energyKcalPer100g': 410, 'proteinPer100g': 10},
          }
        ],
        shoppingItems: const [],
        exportedAt: DateTime.utc(2026, 11, 25, 10, 0),
      );

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['summary']['dietEntriesCount'], 1);
      expect(decoded['summary']['scansCount'], 1);

      final dietCsv = DataExportService.buildDietLogsCsv([
        {
          'date': '2026-11-25',
          'name': '=CMD("calc"), Oats',
          'calories': 320,
        }
      ]);
      expect(dietCsv, contains('"\'=CMD(""calc""), Oats"'));

      final scanCsv = DataExportService.buildScanHistoryCsv([
        {
          'barcode': '8901234567890',
          'name': '+Danger, Bar',
          'safetyStatus': 'safe',
        }
      ]);
      expect(scanCsv, contains('"\'+Danger, Bar"'));
    });

    testWidgets('DataExportDialog renders counts and switches JSON/CSV format',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDataExportDialog(
                  context,
                  onCollectOverride: () async => UserExportBundle(
                    exportedAt: DateTime.utc(2026, 11, 25),
                    account: {'uid': 'u1'},
                    profile: {'name': 'Asha'},
                    consent: null,
                    dietEntries: [
                      {'date': '2026-11-25', 'name': 'Idli', 'calories': 210}
                    ],
                    scans: [
                      {'barcode': '890111', 'name': 'Ragi Bites'}
                    ],
                    shoppingItems: const [],
                    mealPlan: null,
                  ),
                ),
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(
          find.text('1 meals · 1 scans · 0 shopping items'), findsOneWidget);
      expect(find.textContaining('"exportedAt"'), findsOneWidget);

      await tester.tap(find.text('Diet Logs CSV'));
      await tester.pumpAndSettle();
      expect(find.textContaining('date,time,meal_type,name'), findsOneWidget);
    });
  });
}
