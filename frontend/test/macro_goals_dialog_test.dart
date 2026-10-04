import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/widgets/macro_goals_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester, Future<void> Function() save) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => MacroGoalsDialog(proposal: const {
                              'calories': 2500,
                              'protein': 120,
                              'carbs': 300,
                              'fat': 70,
                              'explanation': 'Partial logs; review carefully.'
                            }, onApply: save)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel never mutates goals', (tester) async {
    var calls = 0;
    await open(tester, () async {
      calls++;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Review proposed goals'), findsNothing);
  });
  testWidgets('apply is explicit and duplicate taps submit only once',
      (tester) async {
    var calls = 0;
    final done = Completer<void>();
    await open(tester, () {
      calls++;
      return done.future;
    });
    expect(calls, 0);
    await tester.tap(find.text('Apply Goals'));
    await tester.pump();
    await tester.tap(find.text('Saving…'));
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('Review proposed goals'), findsNothing);
  });
  testWidgets('failed save retains proposal and permits retry', (tester) async {
    await open(tester, () async {
      throw StateError('fixture');
    });
    await tester.tap(find.text('Apply Goals'));
    await tester.pumpAndSettle();
    expect(
        find.text('Goals could not be saved. Please retry.'), findsOneWidget);
    expect(find.text('Apply Goals'), findsOneWidget);
  });
}
