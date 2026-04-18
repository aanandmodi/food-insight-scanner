// lib/core/services/groq_service.dart

import 'package:flutter/foundation.dart';
import 'cloud_function_service.dart';

/// Service to interact with the AI nutrition assistant.
///
/// Previously called the Groq API directly from the device (with the key
/// bundled in assets/env.json).  Now acts as a **thin proxy** over
/// [CloudFunctionService] — the API key lives server-side in Cloud Functions.
///
/// The public API surface is preserved so that existing screens
/// (AiChatAssistant, DietLogScreen, ProductDetails) require minimal changes.
class GroqService {
  static final GroqService _instance = GroqService._internal();
  factory GroqService() => _instance;
  GroqService._internal();

  final CloudFunctionService _cfService = CloudFunctionService();

  /// No-op — kept for backward compat. Initialization is no longer needed
  /// because the API key is server-side.
  Future<void> initialize() async {
    // Nothing to initialise on the client side any more.
  }

  /// No-op — kept for backward compat.
  void reset() {}

  // ──────────────────────────── Chat ────────────────────────────

  /// Generates a response from the AI nutritionist.
  ///
  /// Returns the AI reply text.  Meal-logging intents are handled
  /// server-side by the `chatWithAI` Cloud Function.
  Future<String> generateResponse({
    required String userMessage,
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final result = await _cfService.chatWithAI(
        message: userMessage,
        conversationHistory: conversationHistory,
        userProfile: userProfile,
      );

      return result['reply'] as String? ??
          'I apologize, but I could not generate a response.';
    } catch (e) {
      throw Exception('Failed to generate response: $e');
    }
  }

  /// Generates a response **and** returns full metadata (meal logged flag).
  ///
  /// Use this from [AiChatAssistant] to detect server-side meal logging.
  Future<Map<String, dynamic>> generateResponseWithMeta({
    required String userMessage,
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      return await _cfService.chatWithAI(
        message: userMessage,
        conversationHistory: conversationHistory,
        userProfile: userProfile,
      );
    } catch (e) {
      throw Exception('Failed to generate response: $e');
    }
  }

  // ──────────────────────────── Quick Replies ────────────────────────────

  /// Generates context-aware quick reply suggestions.
  Future<List<String>> generateQuickReplies({
    required String lastUserMessage,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      return await _cfService.generateQuickReplies(
        lastMessage: lastUserMessage,
        userProfile: userProfile,
      );
    } catch (e) {
      debugPrint('Quick replies error: $e');
      return _getDefaultQuickReplies(userProfile);
    }
  }

  // ──────────────────────────── Product Analysis ────────────────────────────

  /// Analyzes a scanned product using AI for personalized advice.
  ///
  /// Note: when scanning via the Cloud Function `scanProduct`, analysis is
  /// already included in the response.  This method is kept for on-demand
  /// analysis of products already loaded from the local cache.
  Future<String> analyzeProduct({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    // The scanProduct Cloud Function already returns an aiAnalysis field.
    // Return it if present, otherwise return a generic message.
    final cached = productData['aiAnalysis'] as String?;
    if (cached != null && cached.isNotEmpty) return cached;

    return 'Detailed analysis is available when you scan the product.';
  }

  /// Generates a list of healthy alternatives for a given product.
  Future<List<Map<String, dynamic>>> getHealthyAlternatives({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      return await _cfService.getAlternatives(
        productData: productData,
        userProfile: userProfile,
      );
    } catch (e) {
      debugPrint('Error fetching alternatives: $e');
      return [];
    }
  }

  // ──────────────────────────── Diet Plan ────────────────────────────

  /// Generates a diet plan for the next day based on today's intake and goals.
  Future<Map<String, dynamic>> generateDietPlan({
    required Map<String, dynamic> dailySummary,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      return await _cfService.generateDietPlan(
        dailySummary: dailySummary,
        userProfile: userProfile,
      );
    } catch (e) {
      debugPrint('Error generating diet plan: $e');
      return {'error': e.toString()};
    }
  }

  // ──────────────────────────── Meal Parsing ────────────────────────────

  /// Parses a natural language meal description into nutritional macros.
  Future<Map<String, dynamic>?> parseMeal(String mealDescription) async {
    try {
      return await _cfService.parseMeal(mealDescription);
    } catch (e) {
      debugPrint('Error parsing meal: $e');
      return null;
    }
  }

  // ──────────────────────────── Helpers ────────────────────────────

  List<String> _getDefaultQuickReplies(Map<String, dynamic>? userProfile) {
    if (userProfile != null && userProfile['allergies'] != null) {
      final allergies = userProfile['allergies'] as List;
      if (allergies.isNotEmpty) {
        return [
          "Safe foods for ${allergies.first} allergy",
          "Check ingredients for allergens",
          "Healthy snack alternatives",
          "Nutrition advice"
        ];
      }
    }
    return [
      "Analyze my last meal",
      "Healthy snack ideas",
      "Check ingredients",
      "Calorie breakdown"
    ];
  }
}
