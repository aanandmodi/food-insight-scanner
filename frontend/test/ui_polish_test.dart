import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:food_insight_scanner/presentation/profile_setup/widgets/dietary_preferences_widget.dart';
import 'package:food_insight_scanner/presentation/ai_chat_assistant/widgets/chat_input_widget.dart';
import 'package:food_insight_scanner/presentation/ai_chat_assistant/widgets/message_bubble_widget.dart';
import 'package:food_insight_scanner/presentation/home_dashboard/widgets/nutrition_summary_card.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester tester, Widget child, double scale) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(Sizer(
        builder: (_, __, ___) => MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(body: SingleChildScrollView(child: child)),
            )));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('diet cards fit and remain selectable at text scale $scale',
        (tester) async {
      List<String> selected = [];
      await show(
          tester,
          DietaryPreferencesWidget(
              selectedPreferences: const [],
              onPreferencesChanged: (value) => selected = value),
          scale);
      await tester.scrollUntilVisible(find.text('Dairy-Free'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Dairy-Free'));
      expect(selected, ['dairy_free']);
      expect(tester.takeException(), isNull);
    });
    testWidgets('summary explanation opens from info at text scale $scale',
        (tester) async {
      await show(tester, const NutritionSummaryCard(nutritionData: {}), scale);
      expect(find.textContaining('These totals include'), findsNothing);
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('These totals include'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('chat composer keeps send visible, prevents empty or busy sends',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final sent = <String>[];
    await show(
        tester,
        ChatInputWidget(
            textController: controller,
            onSendMessage: sent.add),
        2);
    expect(find.byTooltip('Send message'), findsOneWidget);
    await tester.tap(find.byTooltip('Send message'));
    expect(sent, isEmpty);
    await tester.enterText(find.byType(TextField), 'Review my week');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    expect(sent, ['Review my week']);
    expect(controller.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('long AI lists scroll without overflow and expose copying',
      (tester) async {
    await show(
        tester,
        MessageBubbleWidget(
            message: List.generate(
                    25,
                    (i) =>
                        '${i + 1}. **Meal idea** with a full explanation and serving details.')
                .join('\n\n'),
            isUser: false,
            timestamp: DateTime(2026)),
        2);
    expect(find.byTooltip('Copy reply'), findsOneWidget);
    await tester.fling(
        find.byType(SingleChildScrollView), const Offset(0, -700), 1200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
