import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_insight_scanner/core/auth_gate.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Widget gate(
          {String? bound = 'alice',
          bool loading = false,
          bool profile = true,
          bool error = false,
          bool complete = true,
          Future<void> Function()? retry}) =>
      MaterialApp(
          home: AuthGateContent(
              uid: 'alice',
              boundUid: bound,
              loading: loading,
              hasProfile: profile,
              hasError: error,
              complete: complete,
              onRetry: retry ?? () async {},
              dashboard: () => const Text('Dashboard fixture'),
              onboarding: () => const Text('Onboarding fixture')));
  testWidgets('account switch never displays previous owner dashboard',
      (tester) async {
    await tester.pumpWidget(gate(bound: 'bob'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading your profile…'), findsOneWidget);
    expect(find.text('Dashboard fixture'), findsNothing);
    await tester.pumpWidget(gate());
    expect(find.text('Dashboard fixture'), findsOneWidget);
  });
  testWidgets('profile failure offers retry instead of resetting onboarding',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(gate(
        profile: false,
        error: true,
        complete: false,
        retry: () async {
          retries++;
        }));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Onboarding fixture'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
  testWidgets('cached complete profile stays visible during refresh',
      (tester) async {
    await tester.pumpWidget(gate(loading: true));
    expect(find.text('Dashboard fixture'), findsOneWidget);
  });
  testWidgets('new profile goes to onboarding only after load completes',
      (tester) async {
    await tester
        .pumpWidget(gate(profile: false, loading: true, complete: false));
    expect(find.text('Onboarding fixture'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(gate(profile: false, complete: false));
    expect(find.text('Onboarding fixture'), findsOneWidget);
  });
}
