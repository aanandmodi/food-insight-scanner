import 'analytics_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'ai_response_parser.dart';
import 'backend_client.dart';
import 'allergen_safety_service.dart';
import 'user_data_service.dart';
import 'user_session.dart';

class AiRequestException implements Exception {
  final String message;
  final int? statusCode;
  const AiRequestException(this.message, {this.statusCode});
  bool get isRateLimited => statusCode == 429;
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;
  @override
  String toString() => message;
}

/// Authenticated, App Check protected backend interface. No provider key or
/// model instructions are accepted from consumer devices.
class CloudFunctionService {
  static final _instance = CloudFunctionService._();
  factory CloudFunctionService() => _instance;
  CloudFunctionService._();

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    final session = UserSession.instance.capture();
    if (name == 'aiTask') AnalyticsService.record(UsageEvent.aiRequested);
    try {
      final result = await BackendClient.call(name, data);
      session.check();
      if (name == 'aiTask') AnalyticsService.record(UsageEvent.aiSucceeded);
      // Callable maps can have nested platform map generic types.
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(result)) as Map);
    } on FirebaseFunctionsException catch (error) {
      if (name == 'aiTask') {
        AnalyticsService.record(error.code == 'resource-exhausted'
            ? UsageEvent.aiLimited
            : UsageEvent.aiFailed);
      }
      if (error.code == 'not-found') rethrow;
      throw AiRequestException(
          switch (error.code) {
            'resource-exhausted' =>
              error.message ?? 'Daily AI limit reached. Try again tomorrow.',
            'unauthenticated' => 'Your session expired. Please sign in again.',
            'permission-denied' =>
              'This installation could not be verified. Reinstall from Google Play.',
            'failed-precondition' => 'AI is temporarily unavailable.',
            'invalid-argument' =>
              'This request is too large or contains invalid values.',
            'deadline-exceeded' => 'The request timed out. Please retry.',
            _ =>
              'The service is temporarily unavailable. Check your connection and retry.',
          },
          statusCode: switch (error.code) {
            'resource-exhausted' => 429,
            'unauthenticated' => 401,
            'permission-denied' => 403,
            _ => 503,
          });
    } on TimeoutException {
      throw const AiRequestException('The request timed out. Please retry.');
    }
  }

  Future<Map<String, dynamic>> _request(String task, Object content,
          {Map<String, dynamic>? profile}) =>
      _call('aiTask', {
        'task': task,
        'content': content is String ? content : jsonEncode(content),
        'profile': {
          for (final key in [
            'country',
            'region',
            'healthGoals',
            'activityLevel',
            'gender',
            'allergies',
            'dietaryPreferences',
            'age',
            'heightCm',
            'weightKg',
            'customCaloriesGoal',
            'customProteinGoal',
            'customCarbsGoal',
            'customFatGoal'
          ])
            if (profile?[key] != null) key: profile![key]
        },
      });

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
    final plan = AiResponseParser.plan(
        await _request('plan', dailySummary, profile: userProfile));
    validatePlanSafety(plan, userProfile);
    return plan;
  }

  static void validatePlanSafety(
      Map<String, dynamic> plan, Map<String, dynamic>? userProfile) {
    final allergies =
        (userProfile?['allergies'] as List? ?? []).whereType<String>().toList();
    for (final meal in plan['meals'] as List) {
      final ingredients = meal['ingredients'];
      if (ingredients is! List || ingredients.isEmpty) {
        throw const FormatException(
            'Meal ingredient information is incomplete. Please retry.');
      }
      final result = AllergenSafetyService.evaluate({
        'ingredients': ingredients,
        'ingredientsText': '${meal['name']} ${meal['description']}'
      }, allergies);
      if (result.status == AllergenStatus.confirmedConflict ||
          result.status == AllergenStatus.possibleTrace) {
        throw const AiRequestException(
            'This plan conflicts with a reported allergy. Please retry or plan meals manually.');
      }
    }
  }

  Future<Map<String, dynamic>> recalibrateMacrosWithAI(
          {required Map<String, dynamic> userProfile,
          required List<Map<String, dynamic>> recentDietLogs}) =>
      _request('macros', recentDietLogs.take(30).toList(),
          profile: userProfile);

  /// Verified alternatives require an actual catalog comparison and are disabled.
  Future<List<Map<String, dynamic>>> getAlternatives(
          {required Map<String, dynamic> productData,
          Map<String, dynamic>? userProfile}) async =>
      [];

  Future<Map<String, dynamic>> explainProduct(
          {required Map<String, dynamic> productData,
          required Map<String, dynamic> fitResult,
          Map<String, dynamic>? userProfile}) =>
      _request('analysis', {'product': productData, 'foodFit': fitResult},
          profile: userProfile);

  Future<Map<String, dynamic>> chatWithAI(
      {required String message,
      String? conversationHistory,
      Map<String, dynamic>? userProfile,
      String? mealLogContext,
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
          'history': bounded(conversationHistory, 7000),
          'todaysMeals': bounded(mealLogContext, 3000)
        },
        profile: userProfile);
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
          {required String lastMessage,
          Map<String, dynamic>? userProfile}) async =>
      const [
        'Suggest an Indian breakfast',
        'Help me plan a balanced thali',
        'Protein-rich vegetarian snacks'
      ];
}
