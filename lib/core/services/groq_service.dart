import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../main.dart' as main_app;

/// Service to interact with the Groq API for AI chat functionality.
/// Uses Meta Llama 4 Scout model for high-quality nutrition advice.
class GroqService {
  static final GroqService _instance = GroqService._internal();
  factory GroqService() => _instance;
  GroqService._internal();

  String? _apiKey;
  bool _isInitialized = false;

  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'meta-llama/llama-4-scout-17b-16e-instruct';

  /// Initializes the service by reading the API key from the global env.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _apiKey = main_app.env['GROQ_API_KEY'] as String?;

      if (_apiKey == null ||
          _apiKey!.isEmpty ||
          _apiKey == 'your-groq-api-key-here') {
        throw Exception(
            'GROQ_API_KEY not found or not set in assets/env.json. '
            'Get a free key at https://console.groq.com');
      }

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Groq service: $e');
    }
  }

  /// Resets initialization so the service can be re-initialized with a new key.
  void reset() {
    _isInitialized = false;
    _apiKey = null;
  }

  /// Makes an API call with retry logic for transient errors.
  Future<http.Response> _callApi(Map<String, dynamic> body, {int retries = 2}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        // Success or non-retryable error
        if (response.statusCode == 200 ||
            response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 400) {
          return response;
        }

        // Rate limited — wait and retry
        if (response.statusCode == 429 && attempt < retries) {
          final waitMs = (attempt + 1) * 2000;
          debugPrint('Rate limited, waiting ${waitMs}ms before retry...');
          await Future.delayed(Duration(milliseconds: waitMs));
          continue;
        }

        // Server error — retry
        if (response.statusCode >= 500 && attempt < retries) {
          final waitMs = (attempt + 1) * 1000;
          debugPrint('Server error ${response.statusCode}, retrying in ${waitMs}ms...');
          await Future.delayed(Duration(milliseconds: waitMs));
          continue;
        }

        return response;
      } catch (e) {
        if (attempt == retries) rethrow;
        final waitMs = (attempt + 1) * 1000;
        debugPrint('Network error, retrying in ${waitMs}ms: $e');
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    throw Exception('All API call attempts failed');
  }

  /// Generates a response from Groq API.
  Future<String> generateResponse({
    required String userMessage,
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final systemPrompt = _buildSystemPrompt(userProfile);
      final messages = <Map<String, String>>[];

      // System message
      messages.add({'role': 'system', 'content': systemPrompt});

      // Parse conversation history into messages
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final lines = conversationHistory.split('\n');
        for (final line in lines) {
          if (line.startsWith('User: ')) {
            messages.add({'role': 'user', 'content': line.substring(6)});
          } else if (line.startsWith('Assistant: ')) {
            messages.add({'role': 'assistant', 'content': line.substring(11)});
          }
        }
      }

      // Current user message
      messages.add({'role': 'user', 'content': userMessage});

      final response = await _callApi({
        'model': _model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,
        'top_p': 0.95,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          return message['content'] as String? ??
              'I apologize, but I could not generate a response.';
        }
      }

      if (response.statusCode == 401) {
        throw Exception('Invalid API key (401). Please check your Groq API key in assets/env.json.');
      }

      if (response.statusCode == 429) {
        throw Exception('Rate limited (429). Please wait a moment and try again.');
      }

      debugPrint('Groq API error: ${response.statusCode} - ${response.body}');
      throw Exception('Groq API returned status ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to generate response from Groq: $e');
    }
  }

  /// Generates context-aware quick reply suggestions.
  Future<List<String>> generateQuickReplies({
    required String lastUserMessage,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final prompt =
          'Based on the user\'s last message and profile, suggest 4 relevant quick reply options for a nutrition assistant app.\n\n'
          'User\'s last message: "$lastUserMessage"\n'
          '${userProfile != null ? 'User Profile: ${jsonEncode(userProfile)}' : ''}\n\n'
          'Generate 4 short, actionable quick-reply suggestions.\n'
          'Return ONLY the suggestions, one per line, without numbering or bullets.';

      final response = await _callApi({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a helpful nutrition assistant. Respond with only 4 suggestions, one per line.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.8,
        'max_tokens': 256,
      }, retries: 1);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          final text = message['content'] as String? ?? '';
          return text
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .take(4)
              .toList();
        }
      }

      return _getDefaultQuickReplies(userProfile);
    } catch (e) {
      return _getDefaultQuickReplies(userProfile);
    }
  }

  /// Analyzes a scanned product using AI for personalized advice.
  Future<String> analyzeProduct({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final prompt = _buildProductAnalysisPrompt(productData, userProfile);

      final response = await _callApi({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert nutritionist analyzing food products. Provide concise, helpful advice.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.5,
        'max_tokens': 512,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          return message['content'] as String? ?? 'Unable to analyze product.';
        }
      }

      throw Exception('Groq API returned status ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to analyze product: $e');
    }
  }

  /// Generates a list of healthy alternatives for a given product.
  Future<List<Map<String, dynamic>>> getHealthyAlternatives({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final prompt = _buildAlternativesPrompt(productData, userProfile);

      final response = await _callApi({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a nutritionist. Suggest healthier food alternatives as a strict JSON array. Do not include markdown formatting or explanations outside the JSON.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.6,
        'max_tokens': 1024,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          String content = message['content'] as String? ?? '[]';
          
          // Clean up content if it contains markdown code blocks
          content = content.replaceAll('```json', '').replaceAll('```', '').trim();
          
          try {
             // Expecting {"alternatives": [...]} or just [...]
             if (content.startsWith('{')) {
               final data = jsonDecode(content);
               if (data['alternatives'] is List) {
                 return List<Map<String, dynamic>>.from(data['alternatives']);
               }
             } else if (content.startsWith('[')) {
               return List<Map<String, dynamic>>.from(jsonDecode(content));
             }
          } catch (e) {
            debugPrint('Error parsing structured alternatives: $e');
          }
        }
      }
      return []; // Return empty if parsing failed or no result
    } catch (e) {
      debugPrint('Error fetching alternatives: $e');
      return [];
    }
  }

  String _buildAlternativesPrompt(Map<String, dynamic> productData, Map<String, dynamic>? userProfile) {
    return '''
    Based on this product: "${productData['name']}" (Brand: ${productData['brand']}), suggest 3 healthier alternatives specifically available in the **Indian Market**.
    
    User Context:
    ${userProfile != null ? jsonEncode(userProfile) : 'None'}
    
    Output strictly a JSON array of objects. Each object must have:
    - "name": string (Indian product name)
    - "brand": string (Popular Indian brands like Amul, Britannia, Tata Sampann, Yoga Bar, etc.)
    - "image": string (use a placeholder URL like "https://placehold.co/200x200?text=Healthy+Choice")
    - "isBetterChoice": boolean (always true)
    - "healthScore": number (80-100)
    - "price": string (estimate realistic price in INR, e.g. "₹45.00" or "Rs. 150")
    
    Example format:
    {
      "alternatives": [
        {"name": "...", ...}
      ]
    }
    ''';
  }

  /// Generates a diet plan for the next day based on today's intake and goals.
  Future<Map<String, dynamic>> generateDietPlan({
    required Map<String, dynamic> dailySummary,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final prompt = _buildDietPlanPrompt(dailySummary, userProfile);

      final response = await _callApi({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a nutritionist. Create a meal plan for the next day. Output strictly valid JSON.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'max_tokens': 1500,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          String content = message['content'] as String? ?? '{}';
          
          content = content.replaceAll('```json', '').replaceAll('```', '').trim();
          
          try {
            return jsonDecode(content) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('Error parsing diet plan JSON: $e');
            return {'error': 'Failed to parse plan'};
          }
        }
      }
      return {'error': 'API Error'};
    } catch (e) {
      debugPrint('Error generating diet plan: $e');
      return {'error': e.toString()};
    }
  }

  String _buildDietPlanPrompt(Map<String, dynamic> dailySummary, Map<String, dynamic>? userProfile) {
    return '''
    Create a detailed meal plan for TOMORROW based on my intake today and my goals.
    
    Today's Intake Summary:
    - Calories: ${dailySummary['calories']}
    - Protein: ${dailySummary['protein']}g
    - Sugar: ${dailySummary['sugar']}g
    
    My Profile:
    ${userProfile != null ? jsonEncode(userProfile) : 'None'}
    
    Output strictly a JSON object with this structure:
    {
      "summary": "Short overview text...",
      "meals": [
        {
          "type": "Breakfast",
          "name": "...",
          "calories": 300,
          "protein": 10,
          "description": "..."
        },
        {
          "type": "Lunch",
          "name": "...",
          "calories": 500,
          "protein": 25,
          "description": "..."
        },
        {
          "type": "Dinner",
          "name": "...",
          "calories": 600,
          "protein": 30,
          "description": "..."
        },
        {
          "type": "Snack",
          "name": "...",
          "calories": 150,
          "protein": 5,
          "description": "..."
        }
      ],
      "totalCalories": 1550,
      "totalProtein": 70
    }
    ''';
  }

  String _buildSystemPrompt(Map<String, dynamic>? userProfile) {
    String systemPrompt = """
You are an energetic, friendly, and expert nutrition assistant for an Indian food insight scanner app. Your role is to provide personalized dietary advice in a warm, humanized, and highly conversational tone.

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
Never use markdown blocks for the JSON. Just output the exact text string format above so the app can silently log it to their cloud profile.
""";

    if (userProfile != null) {
      systemPrompt += '\n--- User Profile Context ---\n';
      if (userProfile['name'] != null) {
        systemPrompt += '- Name: ${userProfile['name']}\n';
      }
      if (userProfile['allergies'] != null &&
          (userProfile['allergies'] as List).isNotEmpty) {
        systemPrompt +=
            '- Allergies: ${(userProfile['allergies'] as List).join(', ')}\n';
        systemPrompt +=
            '- IMPORTANT: Always warn about these allergens.\n';
      }
      if (userProfile['dietaryPreferences'] != null) {
        systemPrompt +=
            '- Dietary Preference: ${userProfile['dietaryPreferences']}\n';
      }
      if (userProfile['healthGoals'] != null) {
        systemPrompt += '- Health Goals: ${userProfile['healthGoals']}\n';
      }
    }

    return systemPrompt;
  }

  String _buildProductAnalysisPrompt(
      Map<String, dynamic> productData, Map<String, dynamic>? userProfile) {
    final buffer = StringBuffer();
    buffer.writeln('Analyze this food product for me:');
    buffer.writeln('Product: ${productData['name'] ?? 'Unknown'}');
    buffer.writeln('Brand: ${productData['brand'] ?? 'Unknown'}');

    if (productData['nutrition'] != null) {
      final nutrition = productData['nutrition'] as Map<String, dynamic>;
      buffer.writeln('Nutrition per serving:');
      nutrition.forEach((key, value) {
        buffer.writeln('  - $key: $value');
      });
    }

    if (productData['ingredients'] != null) {
      buffer.writeln(
          'Ingredients: ${(productData['ingredients'] as List).join(', ')}');
    }

    if (userProfile != null) {
      buffer.writeln('\nMy profile:');
      if (userProfile['allergies'] != null) {
        buffer.writeln(
            '- Allergies: ${(userProfile['allergies'] as List).join(', ')}');
      }
      if (userProfile['healthGoals'] != null) {
        buffer.writeln('- Health Goal: ${userProfile['healthGoals']}');
      }
    }

    buffer.writeln(
        '\nProvide a brief health analysis and whether this product aligns with my goals.');

    return buffer.toString();
  }

  /// Parses a natural language meal description into nutritional macros
  Future<Map<String, dynamic>?> parseMeal(String mealDescription) async {
    if (!_isInitialized) await initialize();

    try {
      final prompt = 'Analyze the following meal: "$mealDescription"\n'
          'Estimate the macronutrients for a typical Indian serving size if vague.\n'
          'Output strictly as a valid JSON object with these exact keys:\n'
          '{"name": "Brief Meal Name", "calories": <int>, "protein": <double>, "sugar": <double>, "fat": <double>, "carbs": <double>}';

      final response = await _callApi({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a nutrition parser. Return ONLY a valid JSON object matching the requested schema. No markdown.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
      }, retries: 1);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          String content = message['content'] as String? ?? '{}';
          content = content.replaceAll('```json', '').replaceAll('```', '').trim();
          try {
            return jsonDecode(content) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('Failed to parse meal JSON: $e');
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing meal: $e');
      return null;
    }
  }

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
