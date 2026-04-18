import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

/// Service that fetches real product data from the Open Food Facts API.
/// This is a free, open-source database with millions of food products.
/// No API key required.
class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v2/product';

  /// Looks up a product by its barcode. Returns null if not found.
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      final url = '$_baseUrl/$barcode.json';
      debugPrint('Fetching product: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'FoodInsightScanner/1.0 (Flutter App)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        if (json['status'] == 1 && json['product'] != null) {
          final product = json['product'] as Map<String, dynamic>;
          return _parseProduct(barcode, product);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching product: $e');
      return null;
    }
  }

  /// Parses the raw Open Food Facts response into our app's product format.
  Map<String, dynamic> _parseProduct(
      String barcode, Map<String, dynamic> raw) {
    // Extract nutrition data
    final nutriments = raw['nutriments'] as Map<String, dynamic>? ?? {};

    final nutrition = <String, dynamic>{
      'calories':
          (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0,
      'sugar': (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0,
      'protein': (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0,
      'sodium': (nutriments['sodium_100g'] as num?)?.toDouble() ?? 0.0,
      'fiber': (nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0,
      'fat': (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0,
      'carbs':
          (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
    };

    // Extract ingredients list
    final ingredientsText =
        raw['ingredients_text'] as String? ?? '';
    final ingredients = ingredientsText.isNotEmpty
        ? ingredientsText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    // Extract allergens
    final allergensRaw = raw['allergens_tags'] as List? ?? [];
    final allergens = allergensRaw
        .map((e) => (e as String).replaceFirst('en:', ''))
        .toList();

    // Get the best available image
    final imageUrl = raw['image_front_url'] as String? ??
        raw['image_url'] as String? ??
        '';

    return {
      'barcode': barcode,
      'name': raw['product_name'] as String? ?? 'Unknown Product',
      'brand': raw['brands'] as String? ?? 'Unknown Brand',
      'category': raw['categories'] as String? ?? 'Uncategorized',
      'image': imageUrl,
      'nutrition': nutrition,
      'ingredients': ingredients,
      'allergens': allergens,
      'servingSize': raw['serving_size'] as String? ?? 'Per 100g',
      'nutriscore': raw['nutriscore_grade'] as String?,
      'novaGroup': raw['nova_group'] as int?,
      'quantity': raw['quantity'] as String? ?? '',
    };
  }

  /// Saves a scanned product to local history AND Firestore.
  Future<void> saveToScanHistory(Map<String, dynamic> product) async {
    try {
      final entryWithTimestamp = {
        ...product,
        'scannedAt': DateTime.now().toIso8601String(),
      };

      // Save to local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('scan_history') ?? [];

      final entry = jsonEncode(entryWithTimestamp);

      history.insert(0, entry);
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }

      await prefs.setStringList('scan_history', history);

      // Also save to Firestore for cloud sync
      try {
        await FirestoreService().saveScan(product);
      } catch (e) {
        debugPrint('Firestore scan save failed (offline?): $e');
      }

      // Cache product data in Firestore
      try {
        final barcode = product['barcode'] as String?;
        if (barcode != null && barcode.isNotEmpty) {
          await FirestoreService().cacheProduct(barcode, product);
        }
      } catch (e) {
        debugPrint('Firestore product cache failed: $e');
      }
    } catch (e) {
      debugPrint('Error saving scan history: $e');
    }
  }

  /// Gets the scan history — tries Firestore first, falls back to local.
  Future<List<Map<String, dynamic>>> getScanHistory() async {
    // Try Firestore first for logged-in users
    try {
      final firestoreHistory = await FirestoreService()
          .getScanHistory()
          .timeout(const Duration(seconds: 4));
      if (firestoreHistory.isNotEmpty) {
        return firestoreHistory;
      }
    } catch (e) {
      debugPrint('Firestore scan history unavailable: $e');
    }

    // Fall back to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('scan_history') ?? [];

      return history
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error loading local scan history: $e');
      return [];
    }
  }

  /// Clears local-only scan history (used on sign-out).
  Future<void> clearLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scan_history');
    } catch (e) {
      debugPrint('Error clearing local history: $e');
    }
  }
}
