// lib/core/services/cloud_function_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Unified service for calling Firebase Cloud Functions.
///
/// All AI and product-lookup logic now lives server-side;
/// this service is the only client-side gateway to that logic.
class CloudFunctionService {
  static final CloudFunctionService _instance = CloudFunctionService._internal();
  factory CloudFunctionService() => _instance;
  CloudFunctionService._internal();

  /// The Firebase Functions instance configured for the correct region.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Default timeout for callable function invocations.
  static const Duration _timeout = Duration(seconds: 30);

  // ─────────────────────────── Scan Product ───────────────────────────

  /// Looks up a product by barcode via the Cloud Function.
  /// The function checks the Firestore cache, fetches from Open Food Facts
  /// if needed, runs an AI analysis, and returns the complete product data.
  ///
  /// Returns `null` if the product was not found.
  Future<Map<String, dynamic>?> scanProduct(String barcode) async {
    try {
      final callable = _functions.httpsCallable(
        'scanProduct',
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final result = await callable.call<Map<String, dynamic>>({'barcode': barcode});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return null;
      debugPrint('scanProduct error: ${e.code} – ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('scanProduct error: $e');
      rethrow;
    }
  }

  // ─────────────────────────── Parse Meal ───────────────────────────

  /// Parses a natural-language meal description into structured macros.
  ///
  /// Returns `{ name, calories, protein, sugar, fat, carbs }` or `null`
  /// if parsing failed.
  Future<Map<String, dynamic>?> parseMeal(String description) async {
    try {
      final callable = _functions.httpsCallable(
        'parseMeal',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({'description': description});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('parseMeal error: ${e.code} – ${e.message}');
      return null;
    } catch (e) {
      debugPrint('parseMeal error: $e');
      return null;
    }
  }

  // ────────────────────────── Generate Diet Plan ──────────────────────────

  /// Generates a next-day meal plan based on the day's intake summary.
  Future<Map<String, dynamic>> generateDietPlan({
    required Map<String, dynamic> dailySummary,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'generateDietPlan',
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'dailySummary': dailySummary,
        'userProfile': userProfile,
      });
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('generateDietPlan error: ${e.code} – ${e.message}');
      return {'error': e.message ?? 'Failed to generate diet plan'};
    } catch (e) {
      debugPrint('generateDietPlan error: $e');
      return {'error': e.toString()};
    }
  }

  // ────────────────────────── Get Alternatives ──────────────────────────

  /// Returns a list of healthier Indian-market product alternatives.
  Future<List<Map<String, dynamic>>> getAlternatives({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'getAlternatives',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'productData': productData,
        'userProfile': userProfile,
      });
      final data = result.data;
      if (data['alternatives'] is List) {
        return List<Map<String, dynamic>>.from(
          (data['alternatives'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      return [];
    } catch (e) {
      debugPrint('getAlternatives error: $e');
      return [];
    }
  }

  // ────────────────────────── Chat with AI ──────────────────────────

  /// Sends a chat message to the AI nutritionist and returns the reply.
  ///
  /// The response includes:
  /// - `reply` – the AI's response text
  /// - `mealLogged` – whether a meal was auto-logged
  /// - `mealData` – the logged meal data (if any)
  Future<Map<String, dynamic>> chatWithAI({
    required String message,
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'chatWithAI',
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'message': message,
        'conversationHistory': conversationHistory,
        'userProfile': userProfile,
      });
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('chatWithAI error: ${e.code} – ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('chatWithAI error: $e');
      rethrow;
    }
  }

  // ────────────────────────── Quick Replies ──────────────────────────

  /// Gets context-aware quick-reply suggestions.
  Future<List<String>> generateQuickReplies({
    required String lastMessage,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'generateQuickReplies',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'lastMessage': lastMessage,
        'userProfile': userProfile,
      });
      final data = result.data;
      if (data['replies'] is List) {
        return List<String>.from(data['replies'] as List);
      }
      return _defaultReplies;
    } catch (e) {
      debugPrint('generateQuickReplies error: $e');
      return _defaultReplies;
    }
  }

  static const List<String> _defaultReplies = [
    'Analyze my last meal',
    'Healthy snack ideas',
    'Check ingredients',
    'Calorie breakdown',
  ];
}
