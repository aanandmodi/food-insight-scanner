import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:food_insight_scanner/core/auth_gate.dart';
import 'package:food_insight_scanner/presentation/auth/legal_consent_gate_screen.dart';
import 'package:food_insight_scanner/presentation/auth/login_screen/login_screen.dart';
import 'package:food_insight_scanner/presentation/auth/signup_screen/signup_screen.dart';
import 'package:food_insight_scanner/services/consent_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    PackageInfo.setMockInitialValues(
      appName: 'Food Insight',
      packageName: 'com.food_insight_scanner.app',
      version: '1.0.2',
      buildNumber: '2004',
      buildSignature: '',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ConsentService.instance.updateRequiredVersions(
      termsVersion: ConsentService.currentTermsVersion,
      privacyVersion: ConsentService.currentPrivacyVersion,
    );
    await ConsentService.instance.clearPendingConsent();
  });

  group('LegalConsentRecord & ConsentService', () {
    test('matchesRequired requires matching versions and health consent', () {
      final now = DateTime.utc(2026, 11, 25);
      final valid = LegalConsentRecord(
        termsVersion: '2026-09-30',
        privacyVersion: '2026-09-30',
        healthDataConsent: true,
        acceptedAt: now,
        appVersion: '1.0.2+2004',
      );
      expect(valid.matchesRequired('2026-09-30', '2026-09-30'), isTrue);
      expect(valid.matchesRequired('2026-12-01', '2026-09-30'), isFalse);
      expect(valid.matchesRequired('2026-09-30', '2026-12-01'), isFalse);

      final withoutHealth = LegalConsentRecord(
        termsVersion: '2026-09-30',
        privacyVersion: '2026-09-30',
        healthDataConsent: false,
        acceptedAt: now,
      );
      expect(
        withoutHealth.matchesRequired('2026-09-30', '2026-09-30'),
        isFalse,
      );

      final roundTrip = LegalConsentRecord.tryFromMap(valid.toJson());
      expect(roundTrip, isNotNull);
      expect(roundTrip!.termsVersion, '2026-09-30');
      expect(roundTrip.privacyVersion, '2026-09-30');
      expect(roundTrip.healthDataConsent, isTrue);

      final supaRow = valid.toSupabaseRow('uid-123');
      expect(supaRow['user_id'], 'uid-123');
      expect(supaRow['health_data_consent'], isTrue);
    });

    test('pre-auth consent invalidates when required version bumps', () async {
      expect(ConsentService.instance.hasPendingPreAuthConsent, isFalse);

      await ConsentService.instance.acceptPreAuthConsent();
      expect(ConsentService.instance.hasPendingPreAuthConsent, isTrue);

      ConsentService.instance.updateRequiredVersions(
        termsVersion: '2026-12-01',
        privacyVersion: ConsentService.currentPrivacyVersion,
      );
      expect(ConsentService.instance.hasPendingPreAuthConsent, isFalse);
    });
  });

  group('AuthGate & LegalConsentGateScreen', () {
    testWidgets('blocks dashboard behind consent gate when requiresConsent is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGateContent(
            uid: 'alice',
            boundUid: 'alice',
            loading: false,
            hasProfile: true,
            hasError: false,
            complete: true,
            requiresConsent: true,
            onRetry: () async {},
            consentGate: () => const Text('Consent Gate Fixture'),
            dashboard: () => const Text('Dashboard Fixture'),
            onboarding: () => const Text('Onboarding Fixture'),
          ),
        ),
      );
      expect(find.text('Consent Gate Fixture'), findsOneWidget);
      expect(find.text('Dashboard Fixture'), findsNothing);
      expect(find.text('Onboarding Fixture'), findsNothing);
    });

    testWidgets('shows loading splash while consent state is still resolving',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGateContent(
            uid: 'alice',
            boundUid: 'alice',
            loading: false,
            hasProfile: true,
            hasError: false,
            complete: true,
            consentLoading: true,
            requiresConsent: false,
            onRetry: () async {},
            dashboard: () => const Text('Dashboard Fixture'),
            onboarding: () => const Text('Onboarding Fixture'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Loading your profile…'), findsOneWidget);
      expect(find.text('Dashboard Fixture'), findsNothing);
    });

    testWidgets('LegalConsentGateScreen requires checkbox before continuing',
        (tester) async {
      var acceptCalls = 0;
      var signOutCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: LegalConsentGateScreen(
            onAcceptOverride: () async => acceptCalls++,
            onSignOutOverride: () async => signOutCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Agree & Continue'));
      await tester.tap(find.text('Agree & Continue'));
      await tester.pumpAndSettle();

      expect(acceptCalls, 0);
      expect(
        find.text(
          'Please check the box above to review and accept our policies before continuing.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Agree & Continue'));
      await tester.tap(find.text('Agree & Continue'));
      await tester.pumpAndSettle();
      expect(acceptCalls, 1);

      await tester.ensureVisible(find.text('Decline & Sign Out'));
      await tester.tap(find.text('Decline & Sign Out'));
      await tester.pumpAndSettle();
      expect(signOutCalls, 1);
    });
  });

  group('LoginScreen & SignupScreen consent enforcement', () {
    testWidgets('LoginScreen requires checkbox before guest entry',
        (tester) async {
      await tester.pumpWidget(
        Sizer(
          builder: (_, __, ___) => const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continue as guest'));
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      expect(ConsentService.instance.hasPendingPreAuthConsent, isFalse);
      expect(
        find.text(
          'Please check the box above to review and accept our policies before continuing.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(ConsentService.instance.hasPendingPreAuthConsent, isTrue);
    });

    testWidgets('SignupScreen highlights missing consent before submitting',
        (tester) async {
      await tester.pumpWidget(
        Sizer(
          builder: (_, __, ___) => const MaterialApp(home: SignupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Please check the box above to review and accept our policies before continuing.',
        ),
        findsOneWidget,
      );
      expect(ConsentService.instance.hasPendingPreAuthConsent, isFalse);
    });
  });
}
