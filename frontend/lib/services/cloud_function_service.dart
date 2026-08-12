// lib/core/services/cloud_function_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_database_service.dart';
import '../core/config/env.dart';

class CloudFunctionService {
  static final CloudFunctionService _instance = CloudFunctionService._internal();
  factory CloudFunctionService() => _instance;
  CloudFunctionService._internal();

  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<Map<String, dynamic>> _callGroq({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    double? topP,
    Map<String, dynamic>? responseFormat,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('groq_api_key') ?? Env.groqApiKey;

    final response = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (topP != null) 'top_p': topP,
        if (responseFormat != null) 'response_format': responseFormat,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
    }

    return jsonDecode(response.body);
  }

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
  Future<Map<String, dynamic>?> scanProduct(String barcode) async {
    return _fetchAndAnalyzeProduct(barcode, asJson: false);
  }

  // ─────────────────────────── Analyze Product ───────────────────────────
  Future<Map<String, dynamic>?> analyzeProduct(String barcode) async {
    return _fetchAndAnalyzeProduct(barcode, asJson: true);
  }

  Future<Map<String, dynamic>?> _fetchAndAnalyzeProduct(String barcode, {required bool asJson}) async {
    try {
      // 1. Fetch from Open Food Facts
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final res = await http.get(
        url,
        headers: {"User-Agent": "FoodInsightScanner/1.0 (FlutterClient)"},
      );

      if (res.statusCode != 200) return null;
      final jsonResponse = jsonDecode(res.body);
      if (jsonResponse['status'] != 1 || jsonResponse['product'] == null) return null;

      final raw = jsonResponse['product'];
      final nutriments = raw['nutriments'] ?? {};
      final ingredientsText = raw['ingredients_text']?.toString() ?? "";
      final allergensTags = raw['allergens_tags'] as List? ?? [];
      
      final nutrition = {
        'calories': (nutriments['energy-kcal_100g'] ?? 0).toDouble(),
        'sugar': (nutriments['sugars_100g'] ?? 0).toDouble(),
        'protein': (nutriments['proteins_100g'] ?? 0).toDouble(),
        'sodium': (nutriments['sodium_100g'] ?? 0).toDouble(),
        'fiber': (nutriments['fiber_100g'] ?? 0).toDouble(),
        'fat': (nutriments['fat_100g'] ?? 0).toDouble(),
        'carbs': (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
      };

      final ingredients = ingredientsText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      final product = {
        'barcode': barcode,
        'name': raw['product_name']?.toString() ?? "Unknown Product",
        'brand': raw['brands']?.toString() ?? "Unknown Brand",
        'category': raw['categories']?.toString() ?? "Uncategorized",
        'image': raw['image_front_url']?.toString() ?? raw['image_url']?.toString() ?? "",
        'nutrition': nutrition,
        'ingredients': ingredients,
        'allergens': allergensTags.map((t) => t.toString().replaceAll('en:', '')).toList(),
        'servingSize': raw['serving_size']?.toString() ?? "Per 100g",
        'nutriscore': raw['nutriscore_grade'],
        'novaGroup': raw['nova_group'],
        'quantity': raw['quantity']?.toString() ?? "",
      };

      // 2. AI Analysis
      dynamic aiAnalysis;
      try {
        final messages = [
          if (asJson)
            {
              "role": "system",
              "content": "You are an expert nutritionist. Provide a strict health analysis of the scanned product and format your response ONLY as valid JSON.\n{\n  \"summary\": \"2-3 sentences concise health analysis mentioning positives and negatives\",\n  \"isHealthy\": boolean,\n  \"warnings\": [\"Array of short warnings if any\"]\n}",
            }
          else
            {
              "role": "system",
              "content": "You are an expert nutritionist. Provide a concise health analysis of the scanned product in 2-3 sentences. Mention positives and negatives.",
            },
          {
            "role": "user",
            "content": "Analyze: ${product['name']} by ${product['brand']}.\nNutrition per 100g: ${jsonEncode(product['nutrition'])}\nIngredients: ${ingredients.join(", ")}",
          }
        ];

        final aiResponse = await _callGroq(
          model: 'llama-3.1-8b-instant',
          messages: messages,
          temperature: asJson ? 0.2 : 0.5,
          maxTokens: 256,
          responseFormat: asJson ? {"type": "json_object"} : null,
        );
        
        final content = aiResponse['choices']?[0]?['message']?['content'] ?? (asJson ? "{}" : "");
        aiAnalysis = asJson ? jsonDecode(content) : content;
      } catch (e) {
        debugPrint('AI analysis failed: $e');
        aiAnalysis = asJson ? {'summary': 'AI analysis unavailable.', 'isHealthy': false, 'warnings': []} : 'AI analysis unavailable.';
      }

      // 3. Cache in Firestore
      final result = {
        ...product,
        'aiAnalysis': aiAnalysis,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      try {
        await FirebaseFirestore.instance.collection('products').doc(barcode).set(
          result,
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Firestore cache failed: $e');
      }
      
      result['lastUpdated'] = DateTime.now().toIso8601String();
      if (asJson) {
         return _parseProductPayload(result);
      } else {
         return result;
      }
    } catch (e) {
      debugPrint('analyzeProduct error: $e');
      return null;
    }
  }

  // ─────────────────────────── Parse Meal ───────────────────────────
  Future<Map<String, dynamic>?> parseMeal(String description) async {
    try {
      final response = await _callGroq(
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            "role": "system",
            "content": "You are a nutrition parser. Given a meal description, estimate the macronutrients for a typical Indian serving size. Return ONLY a valid JSON object with these exact keys: {\"name\": \"Brief Meal Name\", \"calories\": <int>, \"protein\": <number>, \"sugar\": <number>, \"fat\": <number>, \"carbs\": <number>}. No markdown, no explanation, just the JSON object.",
          },
          {
            "role": "user",
            "content": "Analyze this meal: \"$description\"",
          }
        ],
        temperature: 0.1,
        maxTokens: 256,
      );

      final raw = response['choices']?[0]?['message']?['content'] ?? "";
      final cleaned = raw.replaceAll(RegExp(r'```json\s*'), '').replaceAll('```', '').trim();
      
      final parsed = jsonDecode(cleaned);
      return {
        'name': parsed['name'] ?? description,
        'calories': (parsed['calories'] ?? 0).toInt(),
        'protein': (parsed['protein'] ?? 0).toDouble(),
        'sugar': (parsed['sugar'] ?? 0).toDouble(),
        'fat': (parsed['fat'] ?? 0).toDouble(),
        'carbs': (parsed['carbs'] ?? 0).toDouble(),
      };
    } catch (e) {
      debugPrint('parseMeal error: $e');
      return null;
    }
  }

  // ────────────────────────── Generate Diet Plan ──────────────────────────
  Future<Map<String, dynamic>> generateDietPlan({
    required Map<String, dynamic> dailySummary,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      // Build rich profile context for diet plan
      String profileContext = '';
      if (userProfile != null) {
        final dietPrefs = userProfile['dietaryPreferences'];
        final allergies = userProfile['allergies'];
        final diseases = userProfile['diseases'];
        final healthGoal = userProfile['healthGoals'] ?? 'general wellness';
        final activityLevel = userProfile['activityLevel'] ?? 'moderate';
        final name = userProfile['name'] ?? 'User';

        profileContext = '''
User: $name
Health Goal: $healthGoal
Activity Level: $activityLevel
${dietPrefs is List && dietPrefs.isNotEmpty ? 'Dietary Preferences: ${dietPrefs.join(", ")}\nIMPORTANT: Strictly follow these dietary preferences. If the user is Vegetarian, do NOT suggest non-veg meals.' : ''}
${allergies is List && allergies.isNotEmpty ? 'Allergies: ${allergies.join(", ")}\nIMPORTANT: NEVER suggest foods containing these allergens.' : ''}
${diseases is List && diseases.isNotEmpty ? 'Medical Conditions: ${diseases.join(", ")}\nIMPORTANT: Ensure meal suggestions are safe for these conditions.' : ''}
''';
      }

      final prompt = '''Create a detailed meal plan for TOMORROW based on my intake today and my goals.

Today's Intake Summary:
- Calories: ${dailySummary['calories'] ?? 0}
- Protein: ${dailySummary['protein'] ?? 0}g
- Sugar: ${dailySummary['sugar'] ?? 0}g
- Fat: ${dailySummary['fat'] ?? 0}g
- Carbs: ${dailySummary['carbs'] ?? 0}g

My Profile:
$profileContext

Output strictly a JSON object with this structure:
{
  "summary": "Short overview text...",
  "meals": [
    { "type": "Breakfast", "name": "...", "calories": 300, "protein": 10, "description": "..." },
    { "type": "Lunch",     "name": "...", "calories": 500, "protein": 25, "description": "..." },
    { "type": "Dinner",    "name": "...", "calories": 600, "protein": 30, "description": "..." },
    { "type": "Snack",     "name": "...", "calories": 150, "protein": 5,  "description": "..." }
  ],
  "totalCalories": 1550,
  "totalProtein": 70
}''';

      final response = await _callGroq(
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            "role": "system",
            "content": "You are a nutritionist. Create a meal plan for the next day. Output strictly valid JSON. No markdown.",
          },
          {
            "role": "user",
            "content": prompt,
          }
        ],
        temperature: 0.7,
        maxTokens: 1500,
      );

      final raw = response['choices']?[0]?['message']?['content'] ?? "{}";
      final cleaned = raw.replaceAll(RegExp(r'```json\s*'), '').replaceAll('```', '').trim();
      
      return jsonDecode(cleaned);
    } catch (e) {
      debugPrint('generateDietPlan error: $e');
      return {'error': e.toString()};
    }
  }

  // ────────────────────────── Get Alternatives ──────────────────────────
  Future<List<Map<String, dynamic>>> getAlternatives({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final prompt = '''Based on this product: "${productData['name']}" (Brand: ${productData['brand'] ?? "Unknown"}), suggest 3 healthier alternatives specifically available in the **Indian Market**.

User Context:
${userProfile != null ? jsonEncode(userProfile) : "None"}

Output strictly a JSON object. Each object must have:
- "name": string (Indian product name)
- "brand": string (Popular Indian brands like Amul, Britannia, Tata Sampann, Yoga Bar, etc.)
- "image": string (use a placeholder URL like "https://placehold.co/200x200?text=Healthy+Choice")
- "isBetterChoice": boolean (always true)
- "healthScore": number (80-100)
- "price": string (estimate realistic price in INR, e.g. "₹45.00" or "Rs. 150")

Example format:
{
  "alternatives": [
    {"name": "...", "brand": "...", "image": "...", "isBetterChoice": true, "healthScore": 90, "price": "₹120"}
  ]
}''';

      final response = await _callGroq(
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            "role": "system",
            "content": "You are a nutritionist. Suggest healthier food alternatives as a strict JSON object with an 'alternatives' array. No markdown.",
          },
          {
            "role": "user",
            "content": prompt,
          }
        ],
        temperature: 0.6,
        maxTokens: 1024,
      );

      final raw = response['choices']?[0]?['message']?['content'] ?? "{}";
      final cleaned = raw.replaceAll(RegExp(r'```json\s*'), '').replaceAll('```', '').trim();
      
      final parsed = jsonDecode(cleaned);
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(parsed.map((e) => Map<String, dynamic>.from(e)));
      } else if (parsed is Map && parsed['alternatives'] is List) {
        return List<Map<String, dynamic>>.from(
          (parsed['alternatives'] as List).map((e) => Map<String, dynamic>.from(e as Map))
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
      final historyBuffer = StringBuffer();
      String lastUserMessage = '';
      for (final msg in messages) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        historyBuffer.writeln('${role == 'user' ? 'User' : 'Assistant'}: $content');
        if (role == 'user') lastUserMessage = content;
      }

      return await chatWithAI(
        message: lastUserMessage,
        conversationHistory: historyBuffer.toString(),
        userProfile: userProfile is Map ? Map<String, dynamic>.from(userProfile) : null,
      );
    } catch (e) {
      debugPrint('generateResponseWithMeta error: $e');
      return {
        'message': 'An error occurred. Please check your connection and try again.',
      };
    }
  }

  Future<Map<String, dynamic>> chatWithAI({
    required String message,
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
    String? mealLogContext,
  }) async {
    try {
      String systemPrompt = '''You are an energetic, friendly, and expert nutrition assistant for an Indian food insight scanner app. Your role is to provide personalized dietary advice in a warm, humanized, and highly conversational tone.

**Your Personality & Formatting Rules:**
- **Be Conversational & Energetic:** Talk to the user like a helpful friend. Use fun emojis! 🥑🚀🥗
- **Visual Formatting:** Whenever comparing products or breaking down macros (Calories, Protein, Carbs, Fat), always use **Markdown Tables**.
- **Keep it Clear:** Use bullet points and short, readable paragraphs.
- **Prioritize Safety:** Always warn about allergens and dietary restrictions.

**CRITICAL: Meal Logging Detection**
If the user tells you they just ate something (e.g. "I just had a masala dosa" or "I ate an apple"), you must do TWO things:
1. Respond to them normally in a friendly way.
2. At the very END of your response, output a strict JSON block exactly in this format on its own line:
[LOG_MEAL: {"name": "Meal Name", "calories": 250, "protein": 5, "sugar": 2, "fat": 10, "carbs": 30}]
Never use markdown blocks for the JSON. Just output the exact text string format above so it can be silently logged.''';

      if (userProfile != null) {
        systemPrompt += "\n--- User Profile Context ---\n";
        if (userProfile['name'] != null) systemPrompt += "- Name: ${userProfile['name']}\n";
        if (userProfile['allergies'] != null && (userProfile['allergies'] as List).isNotEmpty) {
          systemPrompt += "- Allergies: ${(userProfile['allergies'] as List).join(", ")}\n";
          systemPrompt += "- IMPORTANT: Always warn about these allergens.\n";
        }
        if (userProfile['dietaryPreferences'] != null) {
          final prefs = userProfile['dietaryPreferences'];
          final prefsStr = prefs is List ? prefs.join(", ") : prefs.toString();
          systemPrompt += "- Dietary Preferences: $prefsStr\n";
          systemPrompt += "- IMPORTANT: Strictly respect these dietary preferences in all suggestions.\n";
        }
        if (userProfile['healthGoals'] != null) {
          systemPrompt += "- Health Goals: ${userProfile['healthGoals']}\n";
        }
        if (userProfile['diseases'] != null && (userProfile['diseases'] as List).isNotEmpty) {
          systemPrompt += "- Medical Conditions: ${(userProfile['diseases'] as List).join(", ")}\n";
        }
        if (userProfile['activityLevel'] != null) {
          systemPrompt += "- Activity Level: ${userProfile['activityLevel']}\n";
        }
      }

      // Inject today's meal log context so AI knows what user ate
      if (mealLogContext != null && mealLogContext.isNotEmpty) {
        systemPrompt += "\n--- Today's Meal Log ---\n$mealLogContext\n";
        systemPrompt += "Use this information to give personalized advice about their remaining nutrition goals for the day.\n";
      }

      final groqMessages = <Map<String, dynamic>>[
        {"role": "system", "content": systemPrompt}
      ];

      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final lines = conversationHistory.split('\n');
        for (final line in lines) {
          if (line.startsWith("User: ")) {
            groqMessages.add({"role": "user", "content": line.substring(6)});
          } else if (line.startsWith("Assistant: ")) {
            groqMessages.add({"role": "assistant", "content": line.substring(11)});
          }
        }
      }
      
      // Make sure the last user message is present
      if (groqMessages.isEmpty || groqMessages.last['role'] != 'user' || groqMessages.last['content'] != message) {
          groqMessages.add({"role": "user", "content": message});
      }

      final response = await _callGroq(
        model: 'llama-3.3-70b-versatile',
        messages: groqMessages,
        temperature: 0.7,
        maxTokens: 1024,
        topP: 0.95,
      );

      String reply = response['choices']?[0]?['message']?['content'] ?? "I apologize, but I could not generate a response.";
      
      bool mealLogged = false;
      Map<String, dynamic>? mealData;

      final logMatch = RegExp(r'\[LOG_MEAL:\s*(\{.*?\})\s*\]', dotAll: true).firstMatch(reply);
      if (logMatch != null) {
        try {
          final macros = jsonDecode(logMatch.group(1)!);
          final now = DateTime.now();
          final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

          final entry = {
            'name': macros['name'] ?? "AI Logged Meal",
            'mealType': "Snack",
            'calories': (macros['calories'] ?? 0).toInt(),
            'protein': (macros['protein'] ?? 0).toDouble(),
            'sugar': (macros['sugar'] ?? 0).toDouble(),
            'fat': (macros['fat'] ?? 0).toDouble(),
            'carbs': (macros['carbs'] ?? 0).toDouble(),
            'brand': "Conversational AI",
            'time': timeString,
            'date': dateString,
            'createdAt': FieldValue.serverTimestamp(),
          };

          await LocalDatabaseService().insertDietEntry(entry);

          try {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await FirebaseFirestore.instance.collection("diet_log").doc(uid).collection("entries").add(entry);
            }
          } catch (_) {}

          mealLogged = true;
          // Don't send FieldValue to client
          mealData = Map.from(entry)..remove('createdAt'); 
          reply = reply.replaceFirst(logMatch.group(0)!, "").trim();
        } catch (e) {
          debugPrint("Failed to parse LOG_MEAL intent: $e");
        }
      }

      return {
        'reply': reply,
        'mealLogged': mealLogged,
        'mealData': mealData,
      };
    } catch (e) {
      debugPrint('chatWithAI error: $e');
      rethrow;
    }
  }

  // ────────────────────────── Quick Replies ──────────────────────────
  Future<List<String>> generateQuickReplies({
    required String lastMessage,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final prompt = 'Based on the user\'s last message and profile, suggest 4 relevant quick reply options for a nutrition assistant app.\n\n'
          'User\'s last message: "$lastMessage"\n'
          '${userProfile != null ? "User Profile: ${jsonEncode(userProfile)}" : ""}\n\n'
          'Generate 4 short, actionable quick-reply suggestions.\n'
          'Return ONLY the suggestions, one per line, without numbering or bullets.';

      final response = await _callGroq(
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            "role": "system",
            "content": "You are a helpful nutrition assistant. Respond with only 4 suggestions, one per line.",
          },
          {
            "role": "user",
            "content": prompt,
          }
        ],
        temperature: 0.8,
        maxTokens: 256,
      );

      final text = response['choices']?[0]?['message']?['content'] ?? "";
      final replies = text
          .split('\n')
          .map((l) => l.toString().trim())
          .where((l) => l.isNotEmpty)
          .take(4)
          .toList();

      return replies.isNotEmpty ? List<String>.from(replies) : _defaultReplies;
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
