import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:food_insight_scanner/presentation/auth/login_screen/login_screen.dart';
import 'package:food_insight_scanner/presentation/auth/signup_screen/signup_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final scale in [1.0, 2.0]) {
    testWidgets('account form fits a small screen at $scale text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(Sizer(
          builder: (_, __, ___) => MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const SignupScreen(),
              )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Already have an account? '));
      await tester.pumpAndSettle();
      expect(find.text('Sign In').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('guest sign-in is reachable on a small screen at $scale text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(Sizer(
          builder: (_, __, ___) => MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const LoginScreen(),
              )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue as guest'));
      await tester.pumpAndSettle();
      expect(find.text('Continue as guest').hitTestable(), findsOneWidget);
      expect(
          tester
              .widget<TextButton>(find
                  .ancestor(
                      of: find.text('Continue as guest'),
                      matching: find
                          .byWidgetPredicate((widget) => widget is TextButton))
                  .first)
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
