import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizer/sizer.dart';
import 'package:food_insight_scanner/presentation/diet_log/widgets/meal_entry_dialog.dart';
import 'package:food_insight_scanner/presentation/settings/account_deletion_dialog.dart';
import 'package:food_insight_scanner/presentation/barcode_scanner/widgets/error_message_widget.dart';
import 'package:food_insight_scanner/presentation/barcode_scanner/widgets/manual_input_widget.dart';

void main() {
  Future<void> dialog(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context, builder: (_) => child),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'AI meal estimate requires review; duplicate save taps submit once',
      (tester) async {
    var saved = 0;
    final pending = Completer<void>();
    await dialog(
        tester,
        MealEntryDialog(
            estimate: (_) async => {
                  'name': 'Rice',
                  'calories': 200,
                  'protein': 4,
                  'carbs': 40,
                  'fat': 2,
                  'sugar': 0
                },
            save: (values) {
              saved++;
              return pending.future;
            }));
    await tester.enterText(find.byType(TextField).first, 'One bowl of rice');
    await tester.tap(find.text('Estimate with AI'));
    await tester.pumpAndSettle();
    expect(saved, 0);
    expect(find.textContaining('review the portion'), findsOneWidget);
    await tester.tap(find.text('Save meal'));
    await tester.pump();
    await tester.tap(find.text('Save meal'));
    expect(saved, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MealEntryDialog), findsNothing);
  });
  testWidgets(
      'manual logging rejects negative nutrition and retains the entered meal',
      (tester) async {
    var saved = 0;
    await dialog(tester, MealEntryDialog(save: (_) async {
      saved++;
    }));
    await tester.enterText(find.byType(TextField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextField).at(1), '-20');
    await tester.tap(find.text('Save meal'));
    await tester.pumpAndSettle();
    expect(saved, 0);
    expect(find.textContaining('must be between'), findsOneWidget);
    expect(find.text('Lunch'), findsWidgets);
  });
  testWidgets('AI rate limit leaves manual entry available', (tester) async {
    await dialog(
        tester,
        MealEntryDialog(
            estimate: (_) async => throw 'Daily AI limit reached.',
            save: (_) async {}));
    await tester.enterText(find.byType(TextField).first, 'Lunch');
    await tester.tap(find.text('Estimate with AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Daily AI limit reached'), findsOneWidget);
    expect(find.textContaining('enter nutrition manually'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
  for (final answer in ['Cancel', 'Delete']) {
    testWidgets('account deletion requires explicit $answer choice',
        (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await confirmAccountDeletion(context);
                      },
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      expect(result, answer == 'Delete');
    });
  }
  testWidgets(
      'scanner failure remains scrollable at large text and retry is actionable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retried = false;
    await tester.pumpWidget(Sizer(
        builder: (_, __, ___) => MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                    body: ErrorMessageWidget(
                        title: 'Product lookup unavailable',
                        message:
                            'Check your internet connection and retry. Saved products remain available in history.',
                        onAction: () => retried = true,
                        onDismiss: () {}))))));
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('manual scanner rejects invalid codes before requesting lookup',
      (tester) async {
    final searches = <String>[];
    await tester.pumpWidget(Sizer(
        builder: (_, __, ___) => MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ManualInputWidget(onSearch: searches.add))))));
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Search Product'));
    await tester.pump();
    expect(searches, isEmpty);
    expect(find.text('Enter an 8–14 digit barcode.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12345678');
    await tester.tap(find.text('Search Product'));
    expect(searches, ['12345678']);
  });
}
