// lib/services/product_service.dart

import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'local_database_service.dart';
import 'cloud_function_service.dart';

/// Outcome of persisting a scan, so the UI can tell the user what actually
/// happened instead of silently dropping the record.
class ScanSaveResult {
  final bool savedLocally;
  final bool savedToCloud;
  final Object? error;

  const ScanSaveResult({
    required this.savedLocally,
    required this.savedToCloud,
    this.error,
  });

  bool get isPersisted => savedLocally || savedToCloud;
}

/// Service that fetches real product data via [CloudFunctionService].
///
/// Local scan history is persisted in SQLite via [LocalDatabaseService].
class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();

  /// Looks up a product by barcode. Returns null if not found.
  ///
  /// Falls back to the local cache when the network lookup fails or times out,
  /// so a previously scanned product still opens offline.
  Future<Map<String, dynamic>?> getProductByBarcode(
    String barcode, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      debugPrint('Fetching product via CloudFunctionService: $barcode');
      final data =
          await CloudFunctionService().analyzeProduct(barcode).timeout(timeout);
      if (data != null) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('Error fetching product $barcode: $e');
    }

    // Offline / failure path — serve the last known good copy if we have one.
    try {
      final cached = await _localDb.getScanByBarcode(barcode);
      if (cached != null) {
        debugPrint('Serving cached local product for $barcode');
        return cached;
      }
    } catch (e) {
      debugPrint('Local product cache miss for $barcode: $e');
    }

    return null;
  }

  /// Saves a scanned product to local SQLite history AND Firestore.
  ///
  /// The two writes are independent: a local failure must not skip the cloud
  /// write (and vice versa), and the caller is told whether anything landed.
  Future<ScanSaveResult> saveToScanHistory(Map<String, dynamic> product) async {
    Object? firstError;
    bool local = false;
    bool cloud = false;

    try {
      local = await _localDb.insertScan(product) > 0;
    } catch (e) {
      firstError ??= e;
      debugPrint('Local scan save failed: $e');
    }

    try {
      cloud = await FirestoreService().saveScan(product);
    } catch (e) {
      firstError ??= e;
      debugPrint('Firestore scan save failed (offline?): $e');
    }

    if (!local && !cloud) {
      debugPrint('WARNING: scan for ${product['barcode']} was not persisted.');
    }

    return ScanSaveResult(
      savedLocally: local,
      savedToCloud: cloud,
      error: firstError,
    );
  }

  /// Gets the scan history — local SQLite first, Firestore as a fallback.
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
          .timeout(const Duration(seconds: 6));
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
