import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_insight_scanner/presentation/ai_chat_assistant/widgets/chat_header_widget.dart';
import 'package:food_insight_scanner/presentation/ai_chat_assistant/widgets/message_bubble_widget.dart';
import 'package:food_insight_scanner/services/backend_client.dart';
import 'package:food_insight_scanner/services/user_data_service.dart';
import 'package:food_insight_scanner/services/user_record_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('BackendClient SSE parser', () {
    test('parses split UTF-8 SSE delta and done frames cleanly', () async {
      final raw = [
        'event: delta\n',
        'data: {"text":"Try "}\n\n',
        'event: delta\ndata: {"te',
        'xt":"2 rotis."}\n\n',
        'event: done\ndata: {"data":{"reply":"Try 2 rotis.","mealData":null}}\n\n',
      ];
      final bytes = Stream<List<int>>.fromIterable(raw.map(utf8.encode));
      final events = await BackendClient.parseSseByteStream(bytes).toList();

      expect(events.length, 3);
      expect(events[0], isA<AiStreamDelta>());
      expect((events[0] as AiStreamDelta).text, 'Try ');
      expect((events[1] as AiStreamDelta).text, '2 rotis.');
      expect(events[2], isA<AiStreamDone>());
      expect((events[2] as AiStreamDone).data['reply'], 'Try 2 rotis.');
    });

    test('maps SSE error event to FirebaseFunctionsException', () async {
      final bytes = Stream<List<int>>.fromIterable([
        utf8.encode(
            'event: error\ndata: {"code":"resource-exhausted","message":"Daily limit reached"}\n\n'),
      ]);

      await expectLater(
        BackendClient.parseSseByteStream(bytes).toList(),
        throwsA(isA<FirebaseFunctionsException>()
            .having((e) => e.code, 'code', 'resource-exhausted')),
      );
    });
  });

  group('Chat sessions storage schema', () {
    test('registers chat_sessions in UserDataService.tables and persists per-session threads',
        () async {
      expect(UserDataService.tables, contains('chat_sessions'));
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await UserRecordStore.createSchema(db);
      final store = UserRecordStore.withDatabase(db);

      await store.put('alice', 'chat_sessions', 'product_8901234567890', {
        'title': 'Masala Oats',
        'kind': 'product',
        'barcode': '8901234567890',
        'updatedAt': '2026-11-26T09:00:00Z',
      });
      await store.put('alice', 'chat_messages', 'm1', {
        'sessionId': 'product_8901234567890',
        'message': 'Is this low GI?',
        'isUser': true,
      });

      final sessions = await store.read('alice', 'chat_sessions');
      final msgs = await store.read('alice', 'chat_messages');
      expect(sessions.length, 1);
      expect(sessions.first['kind'], 'product');
      expect(msgs.single['sessionId'], 'product_8901234567890');
    });
  });

  group('Chat UI components', () {
    testWidgets('ChatHeaderWidget renders history and new chat actions cleanly',
        (tester) async {
      var back = false;
      var history = false;
      var newChat = false;

      await tester.pumpWidget(
        Sizer(
          builder: (_, __, ___) => MaterialApp(
            home: Scaffold(
              body: ChatHeaderWidget(
                title: 'Masala Oats',
                subtitle: 'Product discussion',
                onBackPressed: () => back = true,
                onHistoryPressed: () => history = true,
                onNewChatPressed: () => newChat = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Masala Oats'), findsOneWidget);
      expect(find.text('Product discussion'), findsOneWidget);

      await tester.tap(find.byTooltip('Chat history'));
      await tester.tap(find.byTooltip('New chat'));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));

      expect(history, isTrue);
      expect(newChat, isTrue);
      expect(back, isTrue);
    });

    testWidgets(
        'MessageBubbleWidget transitions cleanly from streaming cursor to copyable final message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MessageBubbleWidget(
                  message: '',
                  isUser: false,
                  isStreaming: true,
                  timestamp: DateTime(2026),
                ),
                MessageBubbleWidget(
                  message: 'Choose 2 rotis with dal.',
                  isUser: false,
                  isStreaming: false,
                  timestamp: DateTime(2026),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Food Insight AI · Streaming…'), findsOneWidget);
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.text('Food Insight AI'), findsOneWidget);
      expect(find.textContaining('Choose 2 rotis', findRichText: true), findsOneWidget);
      expect(find.byTooltip('Copy reply'), findsOneWidget);
    });
  });
}
