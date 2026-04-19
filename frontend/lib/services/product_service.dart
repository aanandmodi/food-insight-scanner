// lib/core/services/product_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firestore_service.dart';
import 'local_database_service.dart';

/// Service that fetches real product data via Cloud Functions.
///
/// Delegates to the `analyzeProduct` Cloud Function which
/// handles OFF fetching, AI analysis, and Admin-SDK Firestore caching.
///
/// Local scan history is persisted in SQLite via [LocalDatabaseService].
class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();

  /// Looks up a product by its barcode via Cloud Function.
  /// Returns null if not found.
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      debugPrint('Fetching product via Cloud Function: $barcode');
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('analyzeProduct');
      final result = await callable.call({'barcode': barcode});
      final data = result.data as Map?;
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

  /// Gets the scan history — tries Firestore first, falls back to local SQLite.
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

    // Fall back to local SQLite storage
    try {
      return await _localDb.getScanHistory();
    } catch (e) {
      debugPrint('Error loading local scan history: $e');
      return [];
    }
  }

  /// Clears local-only scan history (used on sign-out).
  Future<void> clearLocalHistory() async {
    try {
      await _localDb.clearScans();
    } catch (e) {
      debugPrint('Error clearing local history: $e');
    }
  }
}
