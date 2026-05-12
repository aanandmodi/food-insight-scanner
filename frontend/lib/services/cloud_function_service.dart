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

  Map<String, dynamic>? _parseProductPayload(dynamic rawData) {
    try {
      if (rawData is! Map) return null;
      final data = Map<String, dynamic>.from(rawData);
      final nutritionRaw = (data['nutrition'] is Map)
          ? Map<String, dynamic>.from(data['nutrition'] as Map)
          : <String, dynamic>{};
      final aiRaw = (data['aiAnalysis'] is Map)
          ? Map<String, dynamic>.from(data['aiAnalysis'] as Map)
          : <String, dynamic>{};

      return {
        'barcode': '${data['barcode'] ?? ''}',
        'name': '${data['name'] ?? 'Unknown Product'}',
        'brand': '${data['brand'] ?? 'Unknown Brand'}',
        'category': '${data['category'] ?? 'Uncategorized'}',
        'image': '${data['image'] ?? ''}',
        'nutrition': {
          'calories': (nutritionRaw['calories'] as num?)?.toDouble() ?? 0,
          'sugar': (nutritionRaw['sugar'] as num?)?.toDouble() ?? 0,
          'protein': (nutritionRaw['protein'] as num?)?.toDouble() ?? 0,
          'sodium': (nutritionRaw['sodium'] as num?)?.toDouble() ?? 0,
          'fiber': (nutritionRaw['fiber'] as num?)?.toDouble() ?? 0,
          'fat': (nutritionRaw['fat'] as num?)?.toDouble() ?? 0,
          'carbs': (nutritionRaw['carbs'] as num?)?.toDouble() ?? 0,
        },
        'ingredients': (data['ingredients'] as List?)?.cast<dynamic>().map((e) => '$e').toList() ?? <String>[],
        'allergens': (data['allergens'] as List?)?.cast<dynamic>().map((e) => '$e').toList() ?? <String>[],
        'servingSize': '${data['servingSize'] ?? 'Per 100g'}',
        'nutriscore': data['nutriscore'],
        'novaGroup': data['novaGroup'],
        'quantity': '${data['quantity'] ?? ''}',
        'aiAnalysis': {
          'summary': '${aiRaw['summary'] ?? 'AI analysis unavailable.'}',
          'isHealthy': aiRaw['isHealthy'] == true,
          'warnings': (aiRaw['warnings'] as List?)?.cast<dynamic>().map((e) => '$e').toList() ?? <String>[],
        },
        'lastUpdated': '${data['lastUpdated'] ?? ''}',
      };
    } catch (e) {
      debugPrint('parse product payload error: $e');
      return null;
    }
  }

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
      return _parseProductPayload(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return null;
      debugPrint('scanProduct error: ${e.code} – ${e.message}');
      rethrow;
    } on FormatException catch (e) {
      debugPrint('scanProduct format error: ${e.message}');
      return null;
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

  Future<Map<String, dynamic>> generateResponseWithMeta({
    required List<Map<String, String>> messages,
    required dynamic userProfile,
  }) async {
    try {
      // Build conversation history from messages list
      final historyBuffer = StringBuffer();
      String lastUserMessage = '';
      for (final msg in messages) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        historyBuffer.writeln('${role == 'user' ? 'User' : 'Assistant'}: $content');
        if (role == 'user') lastUserMessage = content;
      }

      final callable = _functions.httpsCallable(
        'chatWithAI',
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'message': lastUserMessage,
        'conversationHistory': historyBuffer.toString(),
        'userProfile': userProfile is Map ? userProfile : null,
      });

      return {
        'message': result.data['reply'] as String? ?? 'I couldn\'t generate a response.',
        'mealLogged': result.data['mealLogged'] ?? false,
        'mealData': result.data['mealData'],
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('generateResponseWithMeta error: ${e.code} – ${e.message}');
      return {
        'message': 'I\'m having trouble connecting to the AI service. Please try again.',
      };
    } catch (e) {
      debugPrint('generateResponseWithMeta error: $e');
      return {
        'message': 'An error occurred. Please check your connection and try again.',
      };
    }
  }

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
