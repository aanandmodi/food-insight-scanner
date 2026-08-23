// lib/services/cloud_function_service.dart

import 'dart:async';
import 'dart:convert';

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

// __CFS_CONT__
