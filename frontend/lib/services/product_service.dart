// lib/core/services/product_service.dart

import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'local_database_service.dart';
import 'cloud_function_service.dart';

/// Service that fetches real product data via CloudFunctionService.
///
/// Delegates to the `analyzeProduct` method which
/// handles OFF fetching, AI analysis, and Firestore caching.
///
/// Local scan history is persisted in SQLite via [LocalDatabaseService].
class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();

  /// Looks up a product by its barcode via CloudFunctionService.
  /// Returns null if not found.
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      debugPrint('Fetching product via CloudFunctionService: $barcode');
      final data = await CloudFunctionService().analyzeProduct(barcode);
      if (data != null) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching product: $e');
      return null;
    }
  }

  /// Saves a scanned product to local SQLite history AND Firestore.
  Future<void> saveToScanHistory(Map<String, dynamic> product) async {
    try {
      // Save to local SQLite database
      await _localDb.insertScan(product);

      // Also save to Firestore for cloud sync
      try {
        await FirestoreService().saveScan(product);
      } catch (e) {
        debugPrint('Firestore scan save failed (offline?): $e');
      }

      // Note: product caching in Firestore is now done server-side
      // by the scanProduct Cloud Function using Admin SDK.
    } catch (e) {
      debugPrint('Error saving scan history: $e');
    }
  }

  /// Gets the scan history — reads from local SQLite database first.
  Future<List<Map<String, dynamic>>> getScanHistory() async {
    try {
      final localHistory = await _localDb.getScanHistory();
      if (localHistory.isNotEmpty) {
        return localHistory;
      }
    } catch (e) {
      debugPrint('Error loading local scan history: $e');
    }

    try {
      final firestoreHistory = await FirestoreService()
          .getScanHistory()
          .timeout(const Duration(seconds: 2));
      if (firestoreHistory.isNotEmpty) {
        return firestoreHistory;
      }
    } catch (e) {
      debugPrint('Firestore scan history unavailable: $e');
    }

    return [];
  }

  /// Clears local-only scan history (used on sign-out).
  Future<void> clearLocalHistory() async {
    try {
      await _localDb.clearScans();
    } catch (e) {
      debugPrint('Error clearing local history: $e');
    }
  }

  /// Deletes a scan from local-only history (used when offline/guest).
  Future<void> deleteLocalScan(String barcode) async {
    try {
      await _localDb.deleteScanByBarcode(barcode);
    } catch (e) {
      debugPrint('Error deleting local scan: $e');
    }
  }
}
