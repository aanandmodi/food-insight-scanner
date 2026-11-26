import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'user_session.dart';

sealed class AiStreamEvent {
  const AiStreamEvent();
}

class AiStreamDelta extends AiStreamEvent {
  const AiStreamDelta(this.text);
  final String text;
}

class AiStreamDone extends AiStreamEvent {
  const AiStreamDone(this.data);
  final Map<String, dynamic> data;
}

/// One backend API, two deployment targets. Supabase Free is the default;
/// Firebase Functions remains available when an operator explicitly selects it.
class BackendClient {
  static const transport =
      String.fromEnvironment('BACKEND_TRANSPORT', defaultValue: 'supabase');

  static Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    if (transport == 'firebase') {
      final response = await FirebaseFunctions.instanceFor(
              region: 'asia-south1')
          .httpsCallable(name,
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 110)))
          .call<dynamic>(data);
      return Map<String, dynamic>.from(response.data as Map);
    }
    final appCheck = await FirebaseAppCheck.instance.getToken();
    if (appCheck == null) {
      throw FirebaseFunctionsException(
          code: 'permission-denied', message: 'App verification unavailable.');
    }
    try {
      final response = await SupabaseService.client.functions
          .invoke('food-insight-api', body: {
        'operation': name,
        'data': data
      }, headers: {
        'X-Firebase-AppCheck': appCheck
      }).timeout(const Duration(seconds: 110));
      return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final remote = details is Map ? details['error'] : null;
      throw FirebaseFunctionsException(
          details: remote is Map ? remote['details'] : null,
          code: remote is Map
              ? remote['code'] as String? ?? 'unavailable'
              : 'unavailable',
          message: remote is Map
              ? remote['message'] as String? ??
                  'Service temporarily unavailable.'
              : 'Service temporarily unavailable.');
    }
  }

  /// Parses an HTTP UTF-8 byte stream of Server-Sent Events into typed events.
  static Stream<AiStreamEvent> parseSseByteStream(
      Stream<List<int>> byteStream) async* {
    String eventName = 'message';
    final dataLines = <String>[];

    AiStreamEvent? flushFrame() {
      if (dataLines.isEmpty) {
        eventName = 'message';
        return null;
      }
      final rawData = dataLines.join('\n').trim();
      final currentEvent = eventName;
      eventName = 'message';
      dataLines.clear();
      if (rawData.isEmpty) return null;

      final decoded = jsonDecode(rawData);
      if (currentEvent == 'delta' && decoded is Map) {
        final text = decoded['text']?.toString() ?? '';
        if (text.isNotEmpty) return AiStreamDelta(text);
        return null;
      }
      if (currentEvent == 'done' && decoded is Map && decoded['data'] is Map) {
        return AiStreamDone(Map<String, dynamic>.from(decoded['data'] as Map));
      }
      if (currentEvent == 'error' && decoded is Map) {
        throw FirebaseFunctionsException(
          code: decoded['code']?.toString() ?? 'unavailable',
          message:
              decoded['message']?.toString() ?? 'Service temporarily unavailable.',
        );
      }
      if (decoded is Map && decoded['data'] is Map) {
        return AiStreamDone(Map<String, dynamic>.from(decoded['data'] as Map));
      }
      return null;
    }

    await for (final line
        in byteStream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        final ev = flushFrame();
        if (ev != null) yield ev;
      } else if (line.startsWith(':')) {
        continue;
      } else if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    final trailing = flushFrame();
    if (trailing != null) yield trailing;
  }

  /// Opens an SSE token stream for `aiTask` on Supabase Edge, falling back cleanly to
  /// standard callable invocation when Firebase transport or JSON responses are returned.
  static Stream<AiStreamEvent> streamAiTask(
    Map<String, dynamic> data, {
    HttpClient? httpClient,
    @visibleForTesting Uri? endpointUri,
    @visibleForTesting String? idTokenOverride,
    @visibleForTesting String? appCheckOverride,
  }) async* {
    if (transport == 'firebase' && endpointUri == null) {
      yield AiStreamDone(await call('aiTask', data));
      return;
    }

    final useOverrides =
        endpointUri != null && idTokenOverride != null && appCheckOverride != null;
    SessionToken? session;
    late final String idToken;
    late final String appCheck;
    if (useOverrides) {
      idToken = idTokenOverride;
      appCheck = appCheckOverride;
    } else {
      session = UserSession.instance.capture();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseFunctionsException(
            code: 'unauthenticated', message: 'Sign in to use AI.');
      }
      final fetchedId = await user.getIdToken();
      session.check();
      final fetchedAppCheck = await FirebaseAppCheck.instance.getToken();
      if (fetchedAppCheck == null || fetchedId == null || fetchedId.isEmpty) {
        throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'App verification unavailable.');
      }
      idToken = fetchedId;
      appCheck = fetchedAppCheck;
    }

    final ownedClient = httpClient == null;
    final client = httpClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final uri = endpointUri ??
          Uri.parse('${SupabaseService.url}/functions/v1/food-insight-api');
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.set('apikey', SupabaseService.publicKey);
      request.headers.set('X-Firebase-AppCheck', appCheck);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.write(jsonEncode({
        'operation': 'aiTask',
        'stream': true,
        'data': data,
      }));

      final response = await request.close().timeout(const Duration(seconds: 110));
      session?.check();

      if (response.statusCode != 200) {
        final rawBody = await response.transform(utf8.decoder).join();
        dynamic remote;
        try {
          final parsed = jsonDecode(rawBody);
          if (parsed is Map) remote = parsed['error'];
        } catch (_) {
          // Non-JSON error
        }
        throw FirebaseFunctionsException(
          details: remote is Map ? remote['details'] : null,
          code: remote is Map
              ? remote['code'] as String? ?? 'unavailable'
              : 'unavailable',
          message: remote is Map
              ? remote['message'] as String? ??
                  'Service temporarily unavailable.'
              : 'Service temporarily unavailable.',
        );
      }

      final contentType = response.headers.contentType?.mimeType ?? '';
      if (!contentType.contains('event-stream')) {
        final rawBody = await response.transform(utf8.decoder).join();
        final parsed = jsonDecode(rawBody) as Map;
        yield AiStreamDone(Map<String, dynamic>.from(parsed['data'] as Map));
        return;
      }

      yield* parseSseByteStream(response);
    } finally {
      if (ownedClient) client.close(force: true);
    }
  }
}
