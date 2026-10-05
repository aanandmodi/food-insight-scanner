import 'dart:convert';
import 'package:flutter/services.dart';

class FoodAdditiveService {
  final Map<String, Map<String, dynamic>> _records;
  FoodAdditiveService.fromMap(Map<String, dynamic> data)
      : _records = {
          for (final row in data['additives'] as List)
            row['ins'] as String: Map<String, dynamic>.from(row as Map),
        };
  static Future<FoodAdditiveService>? _loaded;
  static Future<FoodAdditiveService> load() => _loaded ??= rootBundle
      .loadString('assets/data/food_additives_v1.json')
      .then((text) => FoodAdditiveService.fromMap(
          jsonDecode(text) as Map<String, dynamic>));

  static List<String> extract(String text) {
    final pattern = RegExp(
        r'\b(?:INS|E)\s*[-:]?\s*(?:\(\s*(\d{3,4}[a-z]?)\s*\)|(\d{3,4}[a-z]?)(?:\s*\(\s*([ivx]+)\s*\))?)(?![\w]|\s*\()',
        caseSensitive: false);
    return pattern
        .allMatches(text)
        .map((m) =>
            '${(m[1] ?? m[2])!.toLowerCase()}${m[3] == null ? '' : '(${m[3]!.toLowerCase()})'}')
        // OFF's documented lecithin subtype uses e322i for INS 322(i).
        // Keep this alias explicit: arbitrary letter suffixes are not Roman numerals.
        .map((code) => code == '322i' ? '322(i)' : code)
        .toSet()
        .toList();
  }

  List<Map<String, dynamic>> inspect(Map<String, dynamic> product) {
    final codes = extract(
        '${product['ingredientsText'] ?? ''} ${(product['additives'] as List? ?? []).join(' ')}');
    return codes
        .where((code) => code != '322' || !codes.contains('322(i)'))
        .map((code) => {
              'ins': code,
              'known': _records.containsKey(code),
              if (_records[code] != null) ..._records[code]!,
              if (_records[code] == null)
                'name': 'Not in the verified local glossary',
            })
        .toList();
  }
}
