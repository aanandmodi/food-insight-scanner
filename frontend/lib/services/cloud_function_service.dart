// lib/services/cloud_function_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/env.dart';
import 'firestore_service.dart';

/// Raised when the app has no way to reach a model: no server proxy, no
/// dart-defined dev key and nothing entered in Settings. Callers can show a
/// "connect AI" prompt instead of a generic failure.
class AiUnavailableException implements Exception {
  final String message;
  const AiUnavailableException([
    this.message =
        'AI features need an API key. Add one in Settings → AI Assistant.',
  ]);

  @override
  String toString() => message;
}

/// Raised for transport/HTTP failures so the UI can distinguish "offline" from
/// "the model returned something unusable".
class AiRequestException implements Exception {
  final String message;
  final int? statusCode;
  const AiRequestException(this.message, {this.statusCode});

  bool get isRateLimited => statusCode == 429;
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  /// Worth retrying later (as opposed to a bad request we'd just repeat).
  bool get isTransient =>
      statusCode == null || statusCode == 429 || statusCode! >= 500;

  @override
  String toString() => message;
}

class CloudFunctionService {
  static final CloudFunctionService _instance =
      CloudFunctionService._internal();
  factory CloudFunctionService() => _instance;
  CloudFunctionService._internal();

  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Single model for every JSON-shaped task. `openai/gpt-oss-20b` was used for
  /// diet plans and could not honour `response_format`, so plans came back as
  /// prose and `jsonDecode` threw.
  static const String _model = 'llama-3.3-70b-versatile';

  /// Open Food Facts is usually fast but occasionally hangs; without a deadline
  /// a scan could sit on the "Looking up product…" overlay forever.
  static const Duration _offTimeout = Duration(seconds: 12);
  static const Duration _aiTimeout = Duration(seconds: 45);

  /// Product documents older than this get re-fetched. Nutrition data on OFF
  /// changes rarely, so a week keeps repeat scans instant without going stale.
  static const Duration _cacheTtl = Duration(days: 7);

  static const int _maxAttempts = 3;

  final http.Client _client = http.Client();

  /// Cached so we don't hit SharedPreferences on every single AI call.
  String? _memoKey;

  Future<String?> _resolveApiKey() async {
    if (_memoKey != null && _memoKey!.isNotEmpty) return _memoKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('groq_api_key')?.trim();
      if (stored != null && stored.isNotEmpty) {
        _memoKey = stored;
        return stored;
      }
    } catch (e) {
      debugPrint('Could not read stored API key: $e');
    }
    return Env.groqApiKey.isNotEmpty ? Env.groqApiKey : null;
  }

  /// Call after the user edits the key in Settings so the next request picks it
  /// up without an app restart.
  void invalidateKeyCache() => _memoKey = null;

  /// True when this build can actually talk to a model.
  Future<bool> get isConfigured async {
    if (Env.useAiProxy) return true;
    final key = await _resolveApiKey();
    return key != null && key.isNotEmpty;
  }

  // ─────────────────────────────── Transport ───────────────────────────────

  /// Every AI call goes through here. Adds the deadline, the retry/backoff
  /// policy and the proxy-vs-direct routing that used to be missing entirely —
  /// a stalled socket previously hung the calling screen indefinitely.
  Future<Map<String, dynamic>> _callGroq({
    required List<Map<String, dynamic>> messages,
    String model = _model,
    double temperature = 0.7,
    int? maxTokens,
    double? topP,
    Map<String, dynamic>? responseFormat,
    Duration timeout = _aiTimeout,
  }) async {
    // With a proxy configured the key lives server-side and never ships in the
    // APK; that is the only production-safe mode.
    final useProxy = Env.useAiProxy;
    String? apiKey;
    if (!useProxy) {
      apiKey = await _resolveApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const AiUnavailableException();
      }
    }

    final uri = Uri.parse(useProxy ? Env.aiProxyUrl : _groqApiUrl);
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (topP != null) 'top_p': topP,
      if (responseFormat != null) 'response_format': responseFormat,
    });

    AiRequestException? lastError;

    // [timeout] bounds the WHOLE call, not each attempt. Applying it per attempt
    // let three 45 s tries plus backoff run for ~136 s, so the scan screen's
    // 25 s budget fired first and a perfectly good product reported "not found".
    final clock = Stopwatch()..start();
    Duration remaining() => timeout - clock.elapsed;

    // Never sleep past the deadline. False when there is no budget left to retry.
    Future<bool> pauseBeforeRetry(Duration delay) async {
      final budget = remaining();
      if (budget <= Duration.zero) return false;
      await Future<void>.delayed(delay < budget ? delay : budget);
      return remaining() > Duration.zero;
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final budget = remaining();
      if (budget <= Duration.zero) break;
      try {
        final response = await _client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (!useProxy) 'Authorization': 'Bearer $apiKey',
              },
              body: body,
            )
            .timeout(budget);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
          throw const AiRequestException(
              'The AI service returned an unexpected response.');
        }

        // A bad key will never succeed on retry — surface it immediately with
        // an instruction the user can act on.
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const AiUnavailableException(
            'Your AI key was rejected. Check it in Settings → AI Assistant.',
          );
        }

        lastError = AiRequestException(
          _friendlyHttpMessage(response.statusCode),
          statusCode: response.statusCode,
        );
        if (!lastError.isTransient || attempt == _maxAttempts) break;
        if (!await pauseBeforeRetry(
          _backoff(attempt, retryAfter: response.headers['retry-after']),
        )) {
          break;
        }
      } on AiUnavailableException {
        rethrow;
      } on TimeoutException {
        lastError = const AiRequestException(
            'The AI service took too long to respond. Please try again.');
        if (attempt == _maxAttempts) break;
        if (!await pauseBeforeRetry(_backoff(attempt))) break;
      } on SocketException {
        // A dead network will not heal in 400 ms; don't burn the retries.
        lastError = const AiRequestException(
            'No internet connection. Reconnect and try again.');
        break;
      } on http.ClientException catch (e) {
        lastError = AiRequestException('Network error: ${e.message}');
        if (attempt == _maxAttempts) break;
        if (!await pauseBeforeRetry(_backoff(attempt))) break;
      } on FormatException {
        lastError =
            const AiRequestException('The AI service returned malformed data.');
        break;
      }
    }

    throw lastError ??
        const AiRequestException('The AI request failed. Please try again.');
  }

  Duration _backoff(int attempt, {String? retryAfter}) {
    final headerSeconds = int.tryParse(retryAfter?.trim() ?? '');
    if (headerSeconds != null && headerSeconds > 0) {
      return Duration(seconds: math.min(headerSeconds, 10));
    }
    return Duration(milliseconds: 400 * math.pow(2, attempt - 1).toInt());
  }

  String _friendlyHttpMessage(int code) {
    switch (code) {
      case 400:
        return "The AI service couldn't process that request.";
      case 404:
        return 'The configured AI model is unavailable. Please update the app.';
      case 429:
        return 'AI is busy right now (rate limited). Try again in a moment.';
      default:
        return code >= 500
            ? 'The AI service is temporarily down. Please try again shortly.'
            : 'AI request failed (HTTP $code).';
    }
  }

  /// Safely digs `choices[0].message.content` out of a completion response.
  /// The old chained `?[0]?['message']?['content']` threw a type error whenever
  /// the API returned an error envelope instead of choices.
  String? _contentOf(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is! Map) return null;
    return message['content']?.toString();
  }

  // ───────────────────────────── JSON extraction ─────────────────────────────

  /// Pulls the first complete JSON value out of a model reply.
  ///
  /// The previous version tested `{`/`}` before `[`/`]`, so an array response
  /// that happened to contain a brace anywhere produced a garbage substring.
  /// This picks whichever delimiter appears first, then walks the string
  /// tracking depth (respecting string literals and escapes) to find its true
  /// match.
  String _extractJson(String content) {
    var cleaned = content
        .replaceAll(RegExp(r'```(?:json|JSON)?'), '')
        .replaceAll('```', '')
        .trim();
    if (cleaned.isEmpty) return '{}';

    final objStart = cleaned.indexOf('{');
    final arrStart = cleaned.indexOf('[');
    if (objStart == -1 && arrStart == -1) return '{}';

    final int start;
    final String open;
    final String close;
    if (arrStart != -1 && (objStart == -1 || arrStart < objStart)) {
      start = arrStart;
      open = '[';
      close = ']';
    } else {
      start = objStart;
      open = '{';
      close = '}';
    }

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == open) {
        depth++;
      } else if (ch == close) {
        depth--;
        if (depth == 0) return cleaned.substring(start, i + 1);
      }
    }

    // Unterminated — the model was cut off by max_tokens. Hand back the tail so
    // the caller's decode fails loudly rather than us silently returning a
    // fragment that parses into nonsense.
    return cleaned.substring(start);
  }

  /// Decodes a model reply into a map, returning null rather than throwing.
  Map<String, dynamic>? _decodeObject(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(_extractJson(raw));
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      debugPrint('Model returned unparseable JSON: $e');
    }
    return null;
  }

  /// Models answer "12 g" or "≈240 kcal" as often as they answer `12`, and
  /// large values often carry thousands separators ("1,800 kcal"). Match the
  /// whole grouped number, then strip the commas before parsing.
  double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final match = RegExp(r'-?\d[\d,]*(\.\d+)?').firstMatch(v);
      if (match != null) {
        return double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
      }
    }
    return 0;
  }

  List<String> _stringList(Object? v) {
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) {
      return v
          .split(RegExp(r'[,\n•]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, dynamic>? _parseProductPayload(dynamic rawData) {
    try {
      if (rawData is! Map) return null;
      final data = rawData.map((k, v) => MapEntry(k.toString(), v));

      final nutritionRaw = data['nutrition'] is Map
          ? (data['nutrition'] as Map).map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{};
      final aiRaw = data['aiAnalysis'] is Map
          ? (data['aiAnalysis'] as Map).map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{};

      final nutrition = <String, dynamic>{
        'calories': _num(nutritionRaw['calories']),
        'sugar': _num(nutritionRaw['sugar']),
        'protein': _num(nutritionRaw['protein']),
        'sodium': _num(nutritionRaw['sodium']),
        'fiber': _num(nutritionRaw['fiber']),
        'fat': _num(nutritionRaw['fat']),
        'carbs': _num(nutritionRaw['carbs']),
      };

      // Open Food Facts is crowd-sourced: plenty of barcodes resolve to a name
      // with no nutrition at all. Flagging that lets the UI say "nutrition data
      // missing" instead of confidently rendering a row of zeros.
      final hasNutrition = nutrition.values.any((v) => v is num && v > 0);

      return {
        'barcode': '${data['barcode'] ?? ''}',
        'name': '${data['name'] ?? 'Unknown Product'}',
        'brand': '${data['brand'] ?? 'Unknown Brand'}',
        'category': '${data['category'] ?? 'Uncategorized'}',
        'image': '${data['image'] ?? ''}',
        'nutrition': nutrition,
        'hasNutritionData': hasNutrition,
        'ingredients': _stringList(data['ingredients']),
        'allergens': _stringList(data['allergens']),
        'servingSize': '${data['servingSize'] ?? 'Per 100g'}',
        'nutriscore': data['nutriscore'],
        'novaGroup': data['novaGroup'],
        'quantity': '${data['quantity'] ?? ''}',
        'aiAnalysis': {
          'summary': '${aiRaw['summary'] ?? 'AI analysis unavailable.'}',
          'isHealthy': aiRaw['isHealthy'] == true,
          'warnings': _stringList(aiRaw['warnings']),
          'microNutrients': aiRaw['microNutrients'],
        },
        'lastUpdated': '${data['lastUpdated'] ?? ''}',
      };
    } catch (e) {
      debugPrint('parse product payload error: $e');
      return null;
    }
  }

  // ─────────────────────────────── Scan Product ───────────────────────────────

  Future<Map<String, dynamic>?> scanProduct(String barcode) =>
      _fetchAndAnalyzeProduct(barcode, asJson: false);

  Future<Map<String, dynamic>?> analyzeProduct(String barcode) =>
      _fetchAndAnalyzeProduct(barcode, asJson: true);

  /// Reads the shared `products/{barcode}` document.
  ///
  /// This cache was being *written* on every scan and never read, so re-scanning
  /// the same item paid for a fresh Open Food Facts round trip and a fresh LLM
  /// call every single time.
  Future<Map<String, dynamic>?> _readProductCache(String barcode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(barcode)
          .get()
          .timeout(const Duration(seconds: 6));

      final data = doc.data();
      if (!doc.exists || data == null) return null;

      final stamp = data['lastUpdated'];
      DateTime? updated;
      if (stamp is Timestamp) {
        updated = stamp.toDate();
      } else if (stamp is String) {
        updated = DateTime.tryParse(stamp);
      }
      if (updated == null || DateTime.now().difference(updated) > _cacheTtl) {
        return null;
      }

      // A row whose analysis previously failed is worse than no cache — it would
      // pin "AI analysis unavailable." on this product for a week.
      final ai = data['aiAnalysis'];
      final summary = ai is Map ? '${ai['summary'] ?? ''}' : '$ai';
      if (summary.trim().isEmpty || summary.contains('unavailable')) {
        return null;
      }

      final normalised = Map<String, dynamic>.from(data);
      normalised['lastUpdated'] = updated.toIso8601String();
      return normalised;
    } catch (e) {
      debugPrint('Product cache read skipped: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchAndAnalyzeProduct(
    String barcode, {
    required bool asJson,
  }) async {
    // 0. Shared cache — instant, free, and still works when Groq is rate limited.
    if (asJson) {
      final cached = await _readProductCache(barcode);
      if (cached != null) {
        debugPrint('Serving cached analysis for $barcode');
        return _parseProductPayload(cached);
      }
    }

    try {
      // 1. Open Food Facts.
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
      );
      final res = await _client.get(
        url,
        headers: const {
          'User-Agent': 'FoodInsightScanner/1.0 (Flutter; Android)',
        },
      ).timeout(_offTimeout);

      if (res.statusCode != 200) return null;

      final jsonResponse = jsonDecode(res.body);
      if (jsonResponse is! Map ||
          jsonResponse['status'] != 1 ||
          jsonResponse['product'] is! Map) {
        return null;
      }

      final raw = jsonResponse['product'] as Map;
      final nutriments =
          raw['nutriments'] is Map ? raw['nutriments'] as Map : const {};
      final ingredientsText = raw['ingredients_text']?.toString() ?? '';
      final allergensTags = raw['allergens_tags'] as List? ?? const [];

      final nutrition = <String, dynamic>{
        'calories': _num(nutriments['energy-kcal_100g']),
        'sugar': _num(nutriments['sugars_100g']),
        'protein': _num(nutriments['proteins_100g']),
        'sodium': _num(nutriments['sodium_100g']),
        'fiber': _num(nutriments['fiber_100g']),
        'fat': _num(nutriments['fat_100g']),
        'carbs': _num(nutriments['carbohydrates_100g']),
      };

      final ingredients = ingredientsText
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final name = raw['product_name']?.toString().trim() ?? '';
      final product = <String, dynamic>{
        'barcode': barcode,
        'name': name.isNotEmpty ? name : 'Unknown Product',
        'brand': raw['brands']?.toString() ?? 'Unknown Brand',
        'category': raw['categories']?.toString() ?? 'Uncategorized',
        'image': raw['image_front_url']?.toString() ??
            raw['image_url']?.toString() ??
            '',
        'nutrition': nutrition,
        'ingredients': ingredients,
        'allergens':
            allergensTags.map((t) => t.toString().replaceAll('en:', '')).toList(),
        'servingSize': raw['serving_size']?.toString() ?? 'Per 100g',
        'nutriscore': raw['nutriscore_grade'],
        'novaGroup': raw['nova_group'],
        'quantity': raw['quantity']?.toString() ?? '',
      };

      // 2. AI analysis — non-fatal. A product without commentary still beats a
      //    dead end, so every failure path still yields a usable payload.
      dynamic aiAnalysis;
      try {
        final messages = <Map<String, dynamic>>[
          {
            'role': 'system',
            'content': asJson
                ? 'You are an expert nutritionist. Analyse the scanned product '
                    'and reply with ONLY valid JSON in this shape:\n'
                    '{"summary": "2-3 sentences covering positives and negatives", '
                    '"isHealthy": true|false, '
                    '"warnings": ["short warning", "..."], '
                    '"microNutrients": {"sodium": "High|Medium|Low|None", '
                    '"fiber": "High|Medium|Low|None", '
                    '"vitamins": "brief assessment", '
                    '"minerals": "brief assessment"}}\n'
                    'If the nutrition values are all zero, say the data is '
                    'incomplete rather than inventing numbers. Never guess values '
                    'that were not provided.'
                : 'You are an expert nutritionist. Give a concise 2-3 sentence '
                    'health analysis of the scanned product covering positives, '
                    'negatives and its sodium/fibre/vitamin/mineral profile. If '
                    'the nutrition data is missing, say so plainly.',
          },
          {
            'role': 'user',
            'content': 'Analyse: ${product['name']} by ${product['brand']}.\n'
                'Nutrition per 100g: ${jsonEncode(nutrition)}\n'
                'Nutri-Score: ${product['nutriscore'] ?? 'unknown'} · '
                'NOVA group: ${product['novaGroup'] ?? 'unknown'}\n'
                'Ingredients: ${ingredients.isEmpty ? 'not listed' : ingredients.join(', ')}',
          },
        ];

        final aiResponse = await _callGroq(
          messages: messages,
          temperature: asJson ? 0.2 : 0.5,
          // 256 truncated the JSON mid-`microNutrients` on most products, so the
          // object never closed and the whole analysis was discarded.
          maxTokens: asJson ? 800 : 400,
          responseFormat: asJson ? const {'type': 'json_object'} : null,
          // The commentary is explicitly non-fatal, so it must not eat the whole
          // scan budget: getProductByBarcode allows 25 s total and the Open Food
          // Facts fetch above already claims up to 12 s. Leaving the 45 s default
          // here meant a slow model tripped the caller's timeout and threw away a
          // product we had successfully fetched — the user saw "not found".
          timeout: const Duration(seconds: 10),
        );

        final content = _contentOf(aiResponse) ?? '';
        if (asJson) {
          aiAnalysis = _decodeObject(content) ?? _unavailableAnalysis();
        } else {
          aiAnalysis = content.trim().isEmpty
              ? 'AI analysis unavailable.'
              : content.trim();
        }
      } on AiUnavailableException catch (e) {
        debugPrint('AI not configured: ${e.message}');
        aiAnalysis = asJson ? _unavailableAnalysis(e.message) : e.message;
      } catch (e) {
        debugPrint('AI analysis failed: $e');
        aiAnalysis = asJson ? _unavailableAnalysis() : 'AI analysis unavailable.';
      }

      final result = <String, dynamic>{...product, 'aiAnalysis': aiAnalysis};

      // 3. Populate the shared cache — but only with a real analysis. Caching a
      //    failure would poison every future scan of this barcode.
      final summaryText = aiAnalysis is Map
          ? '${aiAnalysis['summary'] ?? ''}'
          : '$aiAnalysis';
      if (!summaryText.contains('unavailable') &&
          !summaryText.contains('API key')) {
        try {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(barcode)
              .set(
                {...result, 'lastUpdated': FieldValue.serverTimestamp()},
                SetOptions(merge: true),
              )
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Firestore cache write failed: $e');
        }
      }

      result['lastUpdated'] = DateTime.now().toIso8601String();
      return asJson ? _parseProductPayload(result) : result;
    } on TimeoutException {
      debugPrint('Open Food Facts lookup timed out for $barcode');
      return null;
    } catch (e) {
      debugPrint('analyzeProduct error: $e');
      return null;
    }
  }

  Map<String, dynamic> _unavailableAnalysis([String? message]) => {
        'summary': message ?? 'AI analysis unavailable.',
        'isHealthy': false,
        'warnings': const <String>[],
      };

  // ─────────────────────────────── Parse Meal ───────────────────────────────

  Future<Map<String, dynamic>?> parseMeal(String description) async {
    if (description.trim().isEmpty) return null;
    try {
      final response = await _callGroq(
        messages: [
          const {
            'role': 'system',
            'content':
                'You are a nutrition parser. Given a meal description, estimate '
                    'the macronutrients for a typical serving. Reply with ONLY a '
                    'JSON object using exactly these keys: {"name": "Brief Meal '
                    'Name", "calories": <int>, "protein": <number>, "sugar": '
                    '<number>, "fat": <number>, "carbs": <number>}. No markdown, '
                    'no explanation.',
          },
          {
            'role': 'user',
            'content': 'Analyse this meal: "${description.trim()}"',
          },
        ],
        temperature: 0.1,
        maxTokens: 300,
        responseFormat: const {'type': 'json_object'},
      );

      final parsed = _decodeObject(_contentOf(response));
      if (parsed == null) return null;

      final parsedName = parsed['name']?.toString().trim() ?? '';
      return {
        'name': parsedName.isNotEmpty ? parsedName : description.trim(),
        'calories': _num(parsed['calories']).round(),
        'protein': _num(parsed['protein']),
        'sugar': _num(parsed['sugar']),
        'fat': _num(parsed['fat']),
        'carbs': _num(parsed['carbs']),
      };
    } catch (e) {
      debugPrint('parseMeal error: $e');
      return null;
    }
  }

  // ───────────────────────────── Generate Diet Plan ─────────────────────────────

  Future<Map<String, dynamic>> generateDietPlan({
    required Map<String, dynamic> dailySummary,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final logged = _num(dailySummary['mealsLogged']).round();
      final prompt =
          '''Create a meal plan for TOMORROW based on my intake today and my goals.

Today's logged intake (${logged == 0 ? 'nothing logged yet — plan a balanced day from scratch' : '$logged meal(s) logged'}):
- Calories: ${_num(dailySummary['calories']).round()} kcal
- Protein: ${_num(dailySummary['protein']).round()} g
- Carbs: ${_num(dailySummary['carbs']).round()} g
- Fat: ${_num(dailySummary['fat']).round()} g

My profile:
${_buildProfileContext(userProfile)}

Reply with ONLY this JSON object:
{
  "summary": "2-3 sentence overview explaining the reasoning",
  "meals": [
    {"type": "Breakfast", "name": "...", "calories": 300, "protein": 10, "description": "..."},
    {"type": "Lunch", "name": "...", "calories": 500, "protein": 25, "description": "..."},
    {"type": "Dinner", "name": "...", "calories": 600, "protein": 30, "description": "..."},
    {"type": "Snack", "name": "...", "calories": 150, "protein": 5, "description": "..."}
  ],
  "totalCalories": 1550,
  "totalProtein": 70
}''';

      final response = await _callGroq(
        messages: [
          const {
            'role': 'system',
            'content':
                'You are a registered dietitian. Output strictly valid JSON. No '
                    'markdown and no commentary outside the JSON.',
          },
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.6,
        maxTokens: 1600,
        responseFormat: const {'type': 'json_object'},
      );

      final parsed = _decodeObject(_contentOf(response));
      if (parsed == null) {
        return {
          'error': "The planner's reply couldn't be read. Please try again.",
        };
      }
      return _normaliseDietPlan(parsed);
    } on AiUnavailableException catch (e) {
      return {'error': e.message};
    } on AiRequestException catch (e) {
      return {'error': e.message};
    } catch (e) {
      debugPrint('generateDietPlan error: $e');
      return {'error': 'Could not build a plan right now. Please try again.'};
    }
  }

  /// Guarantees the exact shape the meal-planner UI indexes into, and recomputes
  /// the totals instead of trusting the model's arithmetic (it frequently
  /// reported totals that didn't match its own meals).
  Map<String, dynamic> _normaliseDietPlan(Map<String, dynamic> parsed) {
    final meals = <Map<String, dynamic>>[];
    final rawMeals = parsed['meals'];
    if (rawMeals is List) {
      for (final m in rawMeals) {
        if (m is! Map) continue;
        final meal = m.map((k, v) => MapEntry(k.toString(), v));
        meals.add({
          'type': meal['type']?.toString() ?? 'Meal',
          'name': meal['name']?.toString() ?? 'Suggested meal',
          'calories': _num(meal['calories']).round(),
          'protein': _num(meal['protein']).round(),
          'description': meal['description']?.toString() ?? '',
        });
      }
    }

    final totalCalories =
        meals.fold<int>(0, (sum, m) => sum + (m['calories'] as int));
    final totalProtein =
        meals.fold<int>(0, (sum, m) => sum + (m['protein'] as int));

    return {
      'summary': parsed['summary']?.toString() ??
          'Here is your optimised plan for the day.',
      'meals': meals,
      'totalCalories': totalCalories > 0
          ? totalCalories
          : _num(parsed['totalCalories']).round(),
      'totalProtein':
          totalProtein > 0 ? totalProtein : _num(parsed['totalProtein']).round(),
    };
  }

  String _buildProfileContext(Map<String, dynamic>? userProfile) {
    if (userProfile == null) return 'No profile details available.';

    final name = userProfile['name']?.toString().trim() ?? '';
    final lines = <String>[
      if (name.isNotEmpty) 'Name: $name',
      'Health goal: ${userProfile['healthGoals'] ?? userProfile['healthGoal'] ?? 'general wellness'}',
      'Activity level: ${userProfile['activityLevel'] ?? 'moderate'}',
      'Device timezone: ${DateTime.now().timeZoneName} — infer the region and '
          'suggest local, regional cuisine (e.g. IST → authentic Indian dishes).',
    ];

    final prefs = _stringList(userProfile['dietaryPreferences']);
    if (prefs.isNotEmpty) {
      lines.add('Dietary preferences: ${prefs.join(', ')}');
      lines.add('CRITICAL: follow these strictly. If vegetarian, suggest no '
          'meat, fish or eggs.');
    }
    final allergies = _stringList(userProfile['allergies']);
    if (allergies.isNotEmpty) {
      lines.add('Allergies: ${allergies.join(', ')}');
      lines.add('CRITICAL: never suggest anything containing these allergens.');
    }
    final diseases = _stringList(userProfile['diseases']);
    if (diseases.isNotEmpty) {
      lines.add('Medical conditions: ${diseases.join(', ')}');
      lines.add('CRITICAL: every suggestion must be safe for these conditions.');
    }

    return lines.join('\n');
  }

  // ───────────────────────────── Recalibrate Macros ─────────────────────────────

  Future<Map<String, dynamic>> recalibrateMacrosWithAI({
    required Map<String, dynamic> userProfile,
    required List<Map<String, dynamic>> recentDietLogs,
  }) async {
    try {
      // Trim the payload — a heavy user's week of entries overflowed the context
      // window and the call came back 400.
      final trimmed = recentDietLogs
          .take(40)
          .map((e) => {
                'name': e['name'],
                'date': e['date'],
                'calories': _num(e['calories']).round(),
                'protein': _num(e['protein']).round(),
                'carbs': _num(e['carbs']).round(),
                'fat': _num(e['fat']).round(),
              })
          .toList();

      final prompt =
          '''You are an expert sports nutritionist. Analyse the user's recent dietary habits and recommend custom daily macro goals for their stated health goal.

User profile:
${_buildProfileContext(userProfile)}

Recent diet logs (up to the 40 most recent entries):
${jsonEncode(trimmed)}

Reply with ONLY this JSON object (macros in grams):
{
  "calories": 2000,
  "protein": 150,
  "carbs": 200,
  "fat": 65,
  "explanation": "Why you adjusted these, based on their logs."
}''';

      final response = await _callGroq(
        messages: [
          const {
            'role': 'system',
            'content':
                'You are a nutritionist. Output strictly valid JSON. No markdown.',
          },
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.3,
        maxTokens: 600,
        responseFormat: const {'type': 'json_object'},
      );

      final parsed = _decodeObject(_contentOf(response));
      if (parsed == null) {
        return {'error': "Couldn't read the recommendation. Please try again."};
      }

      final calories = _num(parsed['calories']).round();
      final protein = _num(parsed['protein']).round();
      final carbs = _num(parsed['carbs']).round();
      final fat = _num(parsed['fat']).round();

      // These values get written straight into the user's daily targets, so
      // never accept a medically implausible number from a language model.
      if (calories < 1000 || calories > 6000) {
        return {
          'error':
              'The AI suggested an unsafe calorie target, so nothing was changed.',
        };
      }

      return {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'explanation': parsed['explanation']?.toString() ??
            'Targets updated from your recent logs.',
      };
    } on AiUnavailableException catch (e) {
      return {'error': e.message};
    } on AiRequestException catch (e) {
      return {'error': e.message};
    } catch (e) {
      debugPrint('recalibrateMacrosWithAI error: $e');
      return {'error': 'Could not recalibrate right now. Please try again.'};
    }
  }

  // ───────────────────────────── Get Alternatives ─────────────────────────────

  Future<List<Map<String, dynamic>>> getAlternatives({
    required Map<String, dynamic> productData,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final nutrition = productData['nutrition'];
      final prompt =
          '''Suggest 3 healthier alternatives to this product that a shopper could realistically find in a supermarket.

Product: "${productData['name']}" by ${productData['brand'] ?? 'unknown brand'}
Category: ${productData['category'] ?? 'unknown'}
Nutrition per 100g: ${nutrition is Map ? jsonEncode(nutrition) : 'unknown'}

Shopper context:
${_buildProfileContext(userProfile)}

Rules:
- Only suggest real, widely available products or clearly generic staples.
- Do NOT invent prices, and do NOT invent image links.
- "reason" must name the concrete nutritional improvement (e.g. "about 60% less added sugar").

Reply with ONLY this JSON object:
{
  "alternatives": [
    {"name": "...", "brand": "...", "healthScore": 88, "reason": "...", "swapTip": "one short practical tip"}
  ]
}''';

      final response = await _callGroq(
        messages: [
          const {
            'role': 'system',
            'content':
                'You are a nutritionist recommending healthier swaps. Output a '
                    'strict JSON object with an "alternatives" array. Never '
                    'fabricate prices, URLs, or brands you are unsure about. No '
                    'markdown.',
          },
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.3,
        maxTokens: 900,
        responseFormat: const {'type': 'json_object'},
      );

      final parsed = _decodeObject(_contentOf(response));
      final rawList = parsed?['alternatives'];
      if (rawList is! List) return const [];

      final out = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is! Map) continue;
        final alt = item.map((k, v) => MapEntry(k.toString(), v));
        final name = alt['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;

        var score = _num(alt['healthScore']).round();
        if (score <= 0 || score > 100) score = 80;

        final brand = alt['brand']?.toString().trim() ?? '';
        out.add({
          'name': name,
          'brand': brand.isNotEmpty ? brand : 'Various brands',
          'healthScore': score,
          'reason': alt['reason']?.toString() ?? '',
          'swapTip': alt['swapTip']?.toString() ?? '',
          'isBetterChoice': true,
          // Deliberately empty. The old prompt asked the model for a
          // placehold.co URL and a made-up ₹ price, so every card showed the
          // same grey stub image above a fabricated number.
          'image': '',
        });
        if (out.length == 3) break;
      }
      return out;
    } catch (e) {
      debugPrint('getAlternatives error: $e');
      return const [];
    }
  }

  // ───────────────────────────── Chat with AI ─────────────────────────────

  /// Structured entry point: [messages] is the real turn-by-turn transcript.
  Future<Map<String, dynamic>> generateResponseWithMeta({
    required List<Map<String, String>> messages,
    required dynamic userProfile,
  }) async {
    final history = <Map<String, String>>[];
    var lastUserMessage = '';
    for (final msg in messages) {
      final role = msg['role'] == 'assistant' ? 'assistant' : 'user';
      final content = msg['content'] ?? '';
      if (content.trim().isEmpty) continue;
      history.add({'role': role, 'content': content});
      if (role == 'user') lastUserMessage = content;
    }

    // chatWithAI appends `message` itself, so drop the trailing user turn.
    if (history.isNotEmpty && history.last['role'] == 'user') {
      history.removeLast();
    }

    try {
      return await chatWithAI(
        message: lastUserMessage,
        history: history,
        userProfile:
            userProfile is Map ? Map<String, dynamic>.from(userProfile) : null,
      );
    } on AiUnavailableException catch (e) {
      return {'reply': e.message, 'mealLogged': false, 'mealData': null};
    } on AiRequestException catch (e) {
      return {'reply': e.message, 'mealLogged': false, 'mealData': null};
    } catch (e) {
      debugPrint('generateResponseWithMeta error: $e');
      return {
        'reply':
            'Something went wrong. Please check your connection and try again.',
        'mealLogged': false,
        'mealData': null,
      };
    }
  }

  Future<Map<String, dynamic>> chatWithAI({
    required String message,

    /// Structured prior turns — preferred.
    List<Map<String, String>>? history,

    /// Legacy `"User: …\nAssistant: …"` transcript. Every multi-line reply was
    /// silently shredded into separate turns by this format; pass [history].
    String? conversationHistory,
    Map<String, dynamic>? userProfile,
    String? mealLogContext,
  }) async {
    final groqMessages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _buildChatSystemPrompt(
          userProfile: userProfile,
          mealLogContext: mealLogContext,
        ),
      },
    ];

    if (history != null && history.isNotEmpty) {
      // Cap the window so a long conversation can't overflow the context.
      final windowed =
          history.length > 20 ? history.sublist(history.length - 20) : history;
      for (final turn in windowed) {
        groqMessages.add({
          'role': turn['role'] == 'assistant' ? 'assistant' : 'user',
          'content': turn['content'] ?? '',
        });
      }
    } else if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (final line in conversationHistory.split('\n')) {
        if (line.startsWith('User: ')) {
          groqMessages.add({'role': 'user', 'content': line.substring(6)});
        } else if (line.startsWith('Assistant: ')) {
          groqMessages.add({'role': 'assistant', 'content': line.substring(11)});
        }
      }
    }

    if (message.trim().isNotEmpty) {
      final last = groqMessages.last;
      if (last['role'] != 'user' || last['content'] != message) {
        groqMessages.add({'role': 'user', 'content': message});
      }
    }

    final response = await _callGroq(
      messages: groqMessages,
      temperature: 0.7,
      maxTokens: 1024,
      topP: 0.95,
    );

    var reply = _contentOf(response)?.trim() ?? '';
    if (reply.isEmpty) {
      reply = "I couldn't come up with a reply just then. Mind rephrasing?";
    }

    var mealLogged = false;
    Map<String, dynamic>? mealData;

    final logMatch =
        RegExp(r'\[LOG_MEAL:\s*(\{.*?\})\s*\]', dotAll: true).firstMatch(reply);
    if (logMatch != null) {
      final directive = logMatch.group(0)!;
      try {
        final macros = jsonDecode(logMatch.group(1)!);
        if (macros is Map) {
          final entry = <String, dynamic>{
            'name': macros['name']?.toString() ?? 'AI logged meal',
            'mealType': _mealTypeForNow(DateTime.now()),
            'calories': _num(macros['calories']).round(),
            'protein': _num(macros['protein']),
            'sugar': _num(macros['sugar']),
            'fat': _num(macros['fat']),
            'carbs': _num(macros['carbs']),
            'brand': 'AI Assistant',
            'serving': macros['serving']?.toString() ?? '1 serving',
          };

          // Single write path: this persists to SQLite, mirrors to Firestore and
          // notifies the dashboard. The old code inserted directly into SQLite
          // *and* separately into Firestore, creating two rows for one meal and
          // double-counting the calories.
          await FirestoreService().saveDietEntry(entry);

          mealLogged = true;
          mealData = Map<String, dynamic>.from(entry);
        }
      } catch (e) {
        debugPrint('Failed to parse LOG_MEAL intent: $e');
      }
      // Strip the directive even when parsing failed — the raw
      // `[LOG_MEAL: {...}]` blob used to leak into the chat bubble.
      reply = reply.replaceFirst(directive, '').trim();
    }

    return {'reply': reply, 'mealLogged': mealLogged, 'mealData': mealData};
  }

  String _mealTypeForNow(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'Breakfast';
    if (h < 16) return 'Lunch';
    if (h < 21) return 'Dinner';
    return 'Snack';
  }

  String _buildChatSystemPrompt({
    Map<String, dynamic>? userProfile,
    String? mealLogContext,
  }) {
    final buffer = StringBuffer(
        '''You are an energetic, friendly and expert nutrition assistant inside a food-scanning app. Give personalised dietary advice in a warm, conversational tone.

Personality and formatting rules:
- Talk like a helpful friend. Emojis are welcome. 🥑🥗
- DO NOT use markdown tables, horizontal rules or underscores. Use bullet points (• ) or short numbered lists only when they genuinely help.
- Short, readable paragraphs. Explain any jargon simply.
- Always flag allergens and dietary conflicts before anything else.
- You are not a doctor: for medical questions, recommend a professional.

CRITICAL — meal logging detection:
If the user says they just ate something (e.g. "I just had a masala dosa"), do BOTH:
1. Reply normally and warmly.
2. On the very last line, output exactly:
[LOG_MEAL: {"name": "Meal Name", "calories": 250, "protein": 5, "sugar": 2, "fat": 10, "carbs": 30}]
Never wrap that line in a markdown block. Only emit it when they actually ate something — not when they are merely asking about a food.''');

    if (userProfile != null) {
      buffer.writeln('\n\n--- User profile ---');
      final name = userProfile['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) buffer.writeln('- Name: $name');

      final allergies = _stringList(userProfile['allergies']);
      if (allergies.isNotEmpty) {
        buffer.writeln('- Allergies: ${allergies.join(', ')}');
        buffer.writeln('- IMPORTANT: never suggest these, and warn the user if '
            'they mention eating one.');
      }
      final prefs = _stringList(userProfile['dietaryPreferences']);
      if (prefs.isNotEmpty) {
        buffer.writeln('- Dietary preferences: ${prefs.join(', ')}');
        buffer.writeln(
            '- IMPORTANT: respect these strictly in every suggestion.');
      }
      final goals =
          (userProfile['healthGoals'] ?? userProfile['healthGoal'])?.toString().trim() ??
              '';
      if (goals.isNotEmpty) buffer.writeln('- Health goal: $goals');

      final diseases = _stringList(userProfile['diseases']);
      if (diseases.isNotEmpty) {
        buffer.writeln('- Medical conditions: ${diseases.join(', ')}');
      }
      final activity = userProfile['activityLevel']?.toString().trim() ?? '';
      if (activity.isNotEmpty) buffer.writeln('- Activity level: $activity');
    }

    if (mealLogContext != null && mealLogContext.trim().isNotEmpty) {
      buffer.writeln("\n--- Today's meal log ---");
      buffer.writeln(mealLogContext.trim());
      buffer.writeln(
          'Use this to advise on their remaining nutrition budget for the day.');
    }

    return buffer.toString();
  }

  // ───────────────────────────── Quick Replies ─────────────────────────────

  Future<List<String>> generateQuickReplies({
    required String lastMessage,
    Map<String, dynamic>? userProfile,
  }) async {
    if (lastMessage.trim().isEmpty) return _defaultReplies;
    try {
      final excerpt = lastMessage.length > 600
          ? lastMessage.substring(0, 600)
          : lastMessage;

      final response = await _callGroq(
        messages: [
          const {
            'role': 'system',
            'content':
                'You suggest follow-up prompts for a nutrition assistant. Reply '
                    'with exactly 4 suggestions, one per line, max 6 words each. '
                    'No numbering, no bullets, no quotes.',
          },
          {
            'role': 'user',
            'content': 'The assistant just said: "$excerpt"\n'
                '${userProfile != null ? 'Health goal: ${userProfile['healthGoals'] ?? 'general wellness'}\n' : ''}'
                'Suggest 4 short follow-ups the user might tap.',
          },
        ],
        temperature: 0.8,
        maxTokens: 150,
        // Quick replies are a nicety — never make the user wait 45s for them.
        timeout: const Duration(seconds: 12),
      );

      final text = _contentOf(response) ?? '';
      final replies = text
          .split('\n')
          .map((l) => l
              .trim()
              .replaceFirst(RegExp(r'^\s*(?:[-•*]|\d+[.)])\s*'), '')
              .replaceAll('"', '')
              .trim())
          .where((l) => l.isNotEmpty && l.length <= 48)
          .take(4)
          .toList();

      return replies.length >= 2 ? replies : _defaultReplies;
    } catch (e) {
      debugPrint('generateQuickReplies error: $e');
      return _defaultReplies;
    }
  }

  static const List<String> _defaultReplies = [
    'Analyse my last meal',
    'Healthy snack ideas',
    'Check ingredients',
    'Calorie breakdown',
  ];
}
