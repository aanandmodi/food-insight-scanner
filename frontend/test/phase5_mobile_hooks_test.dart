import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/core/auth_gate.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/food_additives_widget.dart';
import 'package:food_insight_scanner/presentation/product_details/widgets/report_product_sheet.dart';
import 'package:food_insight_scanner/services/app_governance_service.dart';
import 'package:food_insight_scanner/services/cloud_function_service.dart';
import 'package:food_insight_scanner/services/product_report_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  tearDown(() {
    AppGovernanceService.instance.applyFlagsForTest(
      {},
      currentVersion: '',
      overrides: const {},
    );
  });

  test('AppGovernanceService compares semantic versions accurately', () {
    expect(AppGovernanceService.isVersionBelow('1.0.2+2004', '1.0.3'), isTrue);
    expect(AppGovernanceService.isVersionBelow('1.0.2', '1.1.0'), isTrue);
    expect(AppGovernanceService.isVersionBelow('1.0.3', '1.0.3'), isFalse);
    expect(AppGovernanceService.isVersionBelow('1.2.0', '1.0.9'), isFalse);
    expect(AppGovernanceService.isVersionBelow('1.0.2', ''), isFalse);
    expect(AppGovernanceService.isVersionBelow('1.0.2', 'invalid'), isFalse);
  });

  test('AppGovernanceService merges live additive overrides and new INS codes', () {
    final merged = AppGovernanceService.applyAdditiveOverrides(
      product: {
        'ingredientsText': 'Sugar, Water, INS 102, INS 621',
        'ingredients': ['sugar', 'water'],
      },
      baseRows: [
        {'ins': '102', 'name': 'Tartrazine'},
      ],
      overrides: {
        '102': {
          'ins': '102',
          'name': 'Tartrazine (Yellow 5)',
          'category': 'Food color',
          'safety_tier': 'caution',
          'summary': 'Synthetic azo dye.',
          'active': true,
        },
        '621': {
          'ins': '621',
          'name': 'Monosodium Glutamate',
          'category': 'Flavor enhancer',
          'safety_tier': 'info',
          'summary': 'Savory flavor enhancer.',
          'dietary_notes': 'Contains sodium.',
          'active': true,
        },
      },
    );

    expect(merged.length, 2);
    expect(merged.first['name'], 'Tartrazine (Yellow 5)');
    expect(merged.first['safetyTier'], 'caution');
    expect(merged.last['ins'], '621');
    expect(merged.last['dietaryNotes'], 'Contains sodium.');
  });

  test('ProductReportService validates barcode, issue category, and lengths', () {
    expect(ProductReportService.canReportBarcode('8901234567890'), isTrue);
    expect(ProductReportService.canReportBarcode('custom-1'), isFalse);

    final payload = ProductReportService.buildPayload(
      userId: 'user-1',
      barcode: '8901234567890',
      productName: 'Test Biscuit',
      issueType: 'missing_allergen',
      notes: 'Contains soy lecithin on wrapper',
    );
    expect(payload['status'], 'open');
    expect(payload['issue_type'], 'missing_allergen');
    expect(payload['notes'], 'Contains soy lecithin on wrapper');

    expect(
      () => ProductReportService.buildPayload(
        userId: 'user-1',
        barcode: 'bad',
        productName: 'Test',
        issueType: 'other',
      ),
      throwsFormatException,
    );
  });

  test('CloudFunctionService preserves suspension and deletion messages', () {
    expect(
      CloudFunctionService.permissionDeniedMessage(
          'This account has been suspended.'),
      'This account has been suspended.',
    );
    expect(
      CloudFunctionService.permissionDeniedMessage(
          'Account deletion is in progress.'),
      'Account deletion is in progress.',
    );
    expect(
      CloudFunctionService.permissionDeniedMessage('App Check failed'),
      'This installation could not be verified. Reinstall from Google Play.',
    );
  });

  test('CloudFunctionService.mapClientError maps client & Firebase exceptions deterministically',
      () {
    final blocked = CloudFunctionService.mapClientError(
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Your request could not be processed.',
      ),
      StackTrace.current,
      isStream: true,
    );
    expect(blocked.statusCode, 400);
    expect(blocked.isRetryable, isFalse);
    expect(blocked.message, 'Your request could not be processed.');

    final appCheckErr = CloudFunctionService.mapClientError(
      FirebaseException(plugin: 'firebase_app_check', code: 'unknown'),
      StackTrace.current,
      isStream: true,
    );
    expect(appCheckErr.statusCode, 503);
    expect(appCheckErr.isRetryable, isTrue);

    final tlsErr = CloudFunctionService.mapClientError(
      const HandshakeException('TLS fail'),
      StackTrace.current,
      isStream: true,
    );
    expect(tlsErr.statusCode, 503);
    expect(tlsErr.isRetryable, isTrue);

    final fallback = CloudFunctionService.mapClientError(
      StateError('unexpected'),
      StackTrace.current,
    );
    expect(fallback.statusCode, 503);
    expect(fallback.isRetryable, isTrue);
  });

  testWidgets('AuthGateContent shows maintenance and update-required blocks cleanly',
      (tester) async {
    var refreshCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGateContent(
          uid: 'u1',
          boundUid: 'u1',
          loading: false,
          hasProfile: true,
          hasError: false,
          complete: true,
          maintenanceMode: true,
          maintenanceMessage: 'Database upgrade in progress',
          onRefreshGovernance: () async {
            refreshCalls++;
          },
          onRetry: () async {},
          dashboard: () => const Text('Dashboard'),
          onboarding: () => const Text('Onboarding'),
        ),
      ),
    );
    expect(find.text('Scheduled Maintenance'), findsOneWidget);
    expect(find.text('Database upgrade in progress'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    await tester.tap(find.text('Check again'));
    expect(refreshCalls, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGateContent(
          uid: 'u1',
          boundUid: 'u1',
          loading: false,
          hasProfile: true,
          hasError: false,
          complete: true,
          updateRequired: true,
          minAppVersion: '1.1.0',
          currentAppVersion: '1.0.2',
          onRetry: () async {},
          dashboard: () => const Text('Dashboard'),
          onboarding: () => const Text('Onboarding'),
        ),
      ),
    );
    expect(find.text('Update Required'), findsOneWidget);
    expect(find.textContaining('1.1.0'), findsOneWidget);
  });

  testWidgets('ReportProductSheet submits selected issue type and closes',
      (tester) async {
    String? capturedIssue;
    String? capturedNotes;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ReportProductSheet(
                  barcode: '8901234567890',
                  productName: 'Masala Oats',
                  onSubmit: ({
                    required barcode,
                    required productName,
                    required issueType,
                    required notes,
                  }) async {
                    capturedIssue = issueType;
                    capturedNotes = notes;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missing or wrong allergen warning'));
    await tester.enterText(find.byType(TextField), 'Peanut trace missing');
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(capturedIssue, 'missing_allergen');
    expect(capturedNotes, 'Peanut trace missing');
  });

  testWidgets('FoodAdditivesWidget renders admin override tier and summary',
      (tester) async {
    AppGovernanceService.instance.applyFlagsForTest(
      {},
      overrides: {
        '621': {
          'ins': '621',
          'name': 'MSG',
          'category': 'Flavor enhancer',
          'safety_tier': 'caution',
          'summary': 'Admin override summary note.',
          'active': true,
        },
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FoodAdditivesWidget(
            product: {
              'ingredientsText': 'Rice, Salt, INS 621',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INS 621 · MSG'), findsOneWidget);
    expect(find.text('CAUTION'), findsOneWidget);
    expect(find.text('Admin override summary note.'), findsOneWidget);
  });
}
