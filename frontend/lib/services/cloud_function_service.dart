import 'ai_context_builder.dart';
import 'verified_alternatives_service.dart';
import 'analytics_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'ai_response_parser.dart';
import 'auth_service.dart';
import 'backend_client.dart';
import 'allergen_safety_service.dart';
import 'condition_safety_service.dart';
import 'user_data_service.dart';
import 'user_session.dart';

class AiRequestException implements Exception {
  final String message;
  final int? statusCode;
  const AiRequestException(this.message, {this.statusCode});
  bool get isRateLimited => statusCode == 429;
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;
  bool get isRetryable =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode! >= 500;
  @override
  String toString() => message;
}

class ChatStreamChunk {
  const ChatStreamChunk({
    required this.reply,
    required this.isFinal,
    this.mealData,
  });

  final String reply;
  final bool isFinal;
  final Map<String, dynamic>? mealData;
}

/// Authenticated, App Check protected backend interface. No provider key or
/// model instructions are accepted from consumer devices.
class CloudFunctionService {
  static final _instance = CloudFunctionService._();
  factory CloudFunctionService() => _instance;
  CloudFunctionService._();

  AiRequestException _mapFunctionsException(
      FirebaseFunctionsException error, String name) {
    if (name == 'aiTask') {
      AnalyticsService.record(error.code == 'resource-exhausted'
          ? UsageEvent.aiLimited
          : UsageEvent.aiFailed);
    }
    return AiRequestException(
        switch (error.code) {
          'resource-exhausted' =>
            error.message ?? 'Daily AI limit reached. Try again tomorrow.',
          'unauthenticated' => 'Your session expired. Please sign in again.',
          'permission-denied' =>
            'This installation could not be verified. Reinstall from Google Play.',
          'failed-precondition' =>
            error.message ?? 'AI is temporarily unavailable.',
          'invalid-argument' => error.message ??
              'This request is too large or contains invalid values.',
          'deadline-exceeded' => 'The request timed out. Please retry.',
          _ =>
            'The service is temporarily unavailable. Check your connection and retry.',
        },
        statusCode: switch (error.code) {
          'resource-exhausted' => 429,
          'unauthenticated' => 401,
          'permission-denied' => 403,
          'invalid-argument' => 400,
          'failed-precondition' => 412,
          _ => 503,
        });
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    final session = UserSession.instance.capture();
    if (name == 'aiTask' && AuthService().needsEmailVerification) {
      throw const AiRequestException(
        'Please verify your email address in Home or Settings to use AI features. Barcode scanning and manual logs remain available.',
        statusCode: 403,
      );
    }
    if (name == 'aiTask') AnalyticsService.record(UsageEvent.aiRequested);
    try {
      final result = await BackendClient.call(name, data);
      session.check();
      if (name == 'aiTask') AnalyticsService.record(UsageEvent.aiSucceeded);
      // Callable maps can have nested platform map generic types.
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(result)) as Map);
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Backend call $name error (${error.code}): ${error.message}');
      if (error.code == 'not-found') rethrow;
      throw _mapFunctionsException(error, name);
    } on TimeoutException {
      throw const AiRequestException('The request timed out. Please retry.',
          statusCode: 408);
    } on SocketException {
      throw const AiRequestException(
          'No internet connection. Please check your network and retry.',
          statusCode: 503);
    } on HttpException catch (error) {
      debugPrint('Backend call $name HttpException: $error');
      throw const AiRequestException(
          'Connection interrupted. Please check your connection and retry.',
          statusCode: 503);
    } on FormatException catch (error) {
      debugPrint('Backend call $name FormatException: $error');
      throw const AiRequestException(
          'Unexpected response from server. Please retry.',
          statusCode: 503);
    }
  }

  Future<Map<String, dynamic>> _buildTaskPayload(
    String task,
    Object content, {
    Map<String, dynamic>? profile,
    String? barcode,
    String? sessionId,
  }) async {
    final session = UserSession.instance.capture();
    final db = UserDataService();
    profile ??= await db.getUserProfile() ?? {};
    final logs = task == 'meal'
        ? <Map<String, dynamic>>[]
        : await db.getRecentDietLogs();
    final scans = task == 'chat'
        ? await db.getScanHistory(limit: 5)
        : <Map<String, dynamic>>[];
    final activity = task == 'chat' || task == 'macros'
        ? await db.getActivity(DateTime.now().toIso8601String().split('T')[0])
        : null;
    session.check();
    final context = AIContextBuilder.build(
        task: task,
        userProfile: profile,
        logs: logs,
        scans: scans,
        activity: activity);
    final normalizedBarcode = barcode?.trim();
    final normalizedSessionId = sessionId?.trim();
    return {
      'task': task,
      'content': content is String ? content : jsonEncode(content),
      if (normalizedBarcode != null &&
          RegExp(r'^\d{8,14}$').hasMatch(normalizedBarcode))
        'barcode': normalizedBarcode,
      if (normalizedSessionId != null && normalizedSessionId.isNotEmpty)
        'sessionId': normalizedSessionId,
      'context': context,
      'profile': context['profile'],
    };
  }

  Future<Map<String, dynamic>> _request(String task, Object content,
      {Map<String, dynamic>? profile,
      String? barcode,
      String? sessionId}) async {
    final payload = await _buildTaskPayload(
      task,
      content,
      profile: profile,
      barcode: barcode,
      sessionId: sessionId,
    );
    return _call('aiTask', payload);
  }

  Future<Map<String, dynamic>?> scanProduct(String barcode) =>
      analyzeProduct(barcode);
  Future<Map<String, dynamic>?> analyzeProduct(String barcode) async {
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
      throw const FormatException('Enter an 8–14 digit barcode');
    }
    try {
      return await _call('scanProduct', {'barcode': barcode});
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> parseMeal(String description) async =>
      AiResponseParser.meal(await _request('meal', description,
          profile: await UserDataService().getUserProfile()));

  Future<Map<String, dynamic>> generateDietPlan(
      {required Map<String, dynamic> dailySummary,
      Map<String, dynamic>? userProfile}) async {
    userProfile ??= await UserDataService().getUserProfile();
    if (userProfile == null) {
      throw const AiRequestException(
          'Set up your profile before generating a meal plan.');
    }
    final plan = AiResponseParser.plan(await _request(
        'plan',
        'Plan balanced Indian meals using the structured targets, logged intake and recent meals. All nutrition is estimated.',
        profile: userProfile));
    validatePlanSafety(plan, userProfile);
    AnalyticsService.record(UsageEvent.mealPlanGenerated);
    return plan;
  }

  static void validatePlanSafety(
      Map<String, dynamic> plan, Map<String, dynamic>? userProfile) {
    final allergies =
        (userProfile?['allergies'] as List? ?? []).whereType<String>().toList();
    final conditions =
        (userProfile?['diseases'] as List? ?? []).whereType<String>().toList();
    for (final meal in plan['meals'] as List) {
      final ingredients = meal['ingredients'];
      if (ingredients is! List || ingredients.isEmpty) {
        throw const FormatException(
            'Meal ingredient information is incomplete. Please retry.');
      }
      final mealProduct = {
        'ingredients': ingredients,
        'ingredientsText': '${meal['name']} ${meal['description']}'
      };
      final result = AllergenSafetyService.evaluate(mealProduct, allergies);
      if (result.status == AllergenStatus.confirmedConflict ||
          result.status == AllergenStatus.possibleTrace) {
        throw const AiRequestException(
            'This plan conflicts with a reported allergy. Please retry or plan meals manually.');
      }
      final conditionResult = ConditionSafetyService.evaluate(
        mealProduct,
        conditions: conditions,
      );
      if (conditionResult.hasCriticalConflict ||
          conditionResult.conflicts.isNotEmpty) {
        throw const AiRequestException(
            'This plan may conflict with a saved health condition. Please retry or plan meals manually.');
      }
    }
  }

  Future<Map<String, dynamic>> recalibrateMacrosWithAI(
          {required Map<String, dynamic> userProfile,
          required List<Map<String, dynamic>> recentDietLogs}) =>
      _request(
          'macros',
          'Review the structured seven-day aggregate. Keep current targets when evidence is insufficient.',
          profile: userProfile);

  /// Only normalized records from the authenticated catalog endpoint are ranked.
  Future<List<Map<String, dynamic>>> getAlternatives(
      {required Map<String, dynamic> productData,
      Map<String, dynamic>? userProfile}) async {
    AnalyticsService.record(UsageEvent.alternativesRequested);
    final result =
        await _call('alternatives', {'barcode': productData['barcode']});
    return VerifiedAlternativesService.rank(
        productData,
        (result['candidates'] as List? ?? [])
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList(),
        userProfile ?? {});
  }

  Future<Map<String, dynamic>> explainProduct(
          {required Map<String, dynamic> productData,
          required Map<String, dynamic> fitResult,
          Map<String, dynamic>? userProfile}) =>
      _request(
          'analysis',
          {
            'product': AIContextBuilder.productFacts(productData),
            'foodFit': fitResult
          },
          profile: userProfile,
          barcode: productData['barcode']?.toString());

  Stream<ChatStreamChunk> streamChatWithAI({
    required String message,
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
    Map<String, dynamic>? currentProduct,
    Map<String, dynamic>? foodFit,
    String? sessionId,
    String? imageDataUrl,
  }) async* {
    if (message.trim().isEmpty || message.length > 2000) {
      throw const AiRequestException(
          'Please keep messages between 1 and 2,000 characters.');
    }
    if (imageDataUrl != null) {
      throw const AiRequestException(
          'Photo analysis is unavailable in this beta. Describe the meal in text.');
    }
    if (AuthService().needsEmailVerification) {
      throw const AiRequestException(
        'Please verify your email address in Home or Settings to use AI features. Barcode scanning and manual logs remain available.',
        statusCode: 403,
      );
    }

    String bounded(String? value, int length) {
      final text = value ?? '';
      return text.length <= length
          ? text
          : text.substring(text.length - length);
    }

    final payload = await _buildTaskPayload(
      'chat',
      {
        'message': message,
        if (currentProduct != null)
          'currentProduct': AIContextBuilder.productFacts(currentProduct),
        if (foodFit != null) 'foodFit': foodFit,
        'history': bounded(conversationHistory, 7000),
        'contextNote':
            'Use the structured nutrition context for current logged intake.'
      },
      profile: userProfile,
      barcode: currentProduct?['barcode']?.toString(),
      sessionId: sessionId,
    );

    final session = UserSession.instance.capture();
    AnalyticsService.record(UsageEvent.aiRequested);
    final buffer = StringBuffer();
    var receivedDone = false;

    try {
      await for (final event in BackendClient.streamAiTask(payload)) {
        session.check();
        if (event is AiStreamDelta) {
          buffer.write(event.text);
          yield ChatStreamChunk(reply: buffer.toString(), isFinal: false);
        } else if (event is AiStreamDone) {
          receivedDone = true;
          final raw = Map<String, dynamic>.from(
              jsonDecode(jsonEncode(event.data)) as Map);
          if (raw['reply'] is! String) {
            throw const FormatException('Invalid chat reply');
          }
          AnalyticsService.record(UsageEvent.aiSucceeded);
          AnalyticsService.record(UsageEvent.aiChatUsed);
          yield ChatStreamChunk(
            reply: raw['reply'] as String,
            isFinal: true,
            mealData: raw['mealData'] is Map
                ? AiResponseParser.meal(
                    Map<String, dynamic>.from(raw['mealData'] as Map))
                : null,
          );
        }
      }
      if (!receivedDone && buffer.isNotEmpty) {
        AnalyticsService.record(UsageEvent.aiSucceeded);
        AnalyticsService.record(UsageEvent.aiChatUsed);
        yield ChatStreamChunk(reply: buffer.toString(), isFinal: true);
      }
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Stream aiTask error (${error.code}): ${error.message}');
      throw _mapFunctionsException(error, 'aiTask');
    } on TimeoutException {
      throw const AiRequestException('The request timed out. Please retry.',
          statusCode: 408);
    } on SocketException {
      throw const AiRequestException(
          'No internet connection. Please check your network and retry.',
          statusCode: 503);
    } on HttpException catch (error) {
      debugPrint('Stream aiTask HttpException: $error');
      throw const AiRequestException(
          'Stream interrupted. Please check your connection and retry.',
          statusCode: 503);
    } on FormatException catch (error) {
      debugPrint('Stream aiTask FormatException: $error');
      throw const AiRequestException(
          'Unexpected response from AI stream. Please retry.',
          statusCode: 503);
    }
  }

  Future<Map<String, dynamic>> chatWithAI(
      {required String message,
      String? conversationHistory,
      Map<String, dynamic>? userProfile,
      String? mealLogContext,
      Map<String, dynamic>? currentProduct,
      Map<String, dynamic>? foodFit,
      String? sessionId,
      String? imageDataUrl}) async {
    if (message.trim().isEmpty || message.length > 2000) {
      throw const AiRequestException(
          'Please keep messages between 1 and 2,000 characters.');
    }
    if (imageDataUrl != null) {
      throw const AiRequestException(
          'Photo analysis is unavailable in this beta. Describe the meal in text.');
    }
    String bounded(String? value, int length) {
      final text = value ?? '';
      return text.length <= length
          ? text
          : text.substring(text.length - length);
    }

    final result = await _request(
        'chat',
        {
          'message': message,
          if (currentProduct != null)
            'currentProduct': AIContextBuilder.productFacts(currentProduct),
          if (foodFit != null) 'foodFit': foodFit,
          'history': bounded(conversationHistory, 7000),
          'contextNote':
              'Use the structured nutrition context for current logged intake.'
        },
        profile: userProfile,
        barcode: currentProduct?['barcode']?.toString(),
        sessionId: sessionId);
    AnalyticsService.record(UsageEvent.aiChatUsed);
    if (result['reply'] is! String) {
      throw const FormatException('Invalid chat reply');
    }
    // AI never mutates a health record. The chat screen asks the user to confirm.
    return {
      'reply': result['reply'],
      'mealLogged': false,
      if (result['mealData'] is Map)
        'mealData': AiResponseParser.meal(
            Map<String, dynamic>.from(result['mealData'] as Map))
    };
  }

  Future<List<String>> generateQuickReplies(
      {required String lastMessage, Map<String, dynamic>? userProfile}) async {
    const fallback = [
      'Suggest an Indian breakfast',
      'Help me plan a balanced thali',
      'Protein-rich vegetarian snacks'
    ];
    try {
      final result = await _request('quickReplies',
          lastMessage.substring(0, lastMessage.length.clamp(0, 2500)),
          profile: userProfile);
      final replies = (result['replies'] as List).whereType<String>().toList();
      if (replies.length < 2 ||
          replies.length > 4 ||
          replies.any((r) => r.length > 100)) {
        return fallback;
      }
      return replies;
    } catch (_) {
      return fallback;
    }
  }
}
