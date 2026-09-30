import 'analytics_service.dart';
// lib/services/product_service.dart

import 'package:flutter/foundation.dart';
import 'user_data_service.dart';
import 'local_database_service.dart';
import 'cloud_function_service.dart';
import 'product_facts_adapter.dart';

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
    Duration timeout = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    AnalyticsService.record(UsageEvent.scanStarted);
    Map<String, dynamic>? cached;
    try {
      cached = (await UserDataService().cachedScans())
          .where((row) => row['barcode'] == barcode).firstOrNull;
      final fetched = DateTime.tryParse('${cached?['sourceFetchedAt']}');
      if (!forceRefresh && cached?['schemaVersion'] == 2 && fetched != null &&
          DateTime.now().difference(fetched) < const Duration(days: 7)) {
        return ProductFactsAdapter.adapt(cached!);
      }
    } catch (_) {}
    try {
      debugPrint('Fetching product via CloudFunctionService: $barcode');
      final data =
          await CloudFunctionService().analyzeProduct(barcode).timeout(timeout);
      if (data != null) {
        AnalyticsService.record(UsageEvent.scanSucceeded);
        return ProductFactsAdapter.adapt(data);
      }
      AnalyticsService.record(UsageEvent.scanNotFound);
      return null;
    } catch (e) {
      AnalyticsService.record(UsageEvent.scanFailed);
      debugPrint('Error fetching product $barcode: $e');
      if (cached != null) {
        return {...ProductFactsAdapter.adapt(cached), 'isOfflineCopy': true};
      }
      rethrow;
    }
  }

  /// Saves a scanned product to local SQLite history AND Firestore.
  ///
  /// The two writes are independent: a local failure must not skip the cloud
  /// write (and vice versa), and the caller is told whether anything landed.
  Future<ScanSaveResult> saveToScanHistory(Map<String, dynamic> product) async {
    final cloud = await UserDataService().saveScan(product);
    return ScanSaveResult(savedLocally: true, savedToCloud: cloud);
  }

  Future<List<Map<String, dynamic>>> getScanHistory() =>
      UserDataService().getScanHistory();

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
      await UserDataService().deleteScan(barcode);
    } catch (e) {
      debugPrint('Error deleting local scan: $e');
    }
  }
}
