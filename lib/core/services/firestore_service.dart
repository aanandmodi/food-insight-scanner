// lib/core/services/firestore_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user data in Firestore.
/// All methods are resilient to Firebase being unavailable (offline mode).
/// Diet log entries have a SharedPreferences fallback for offline persistence.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Local storage key prefix for diet entries
  static const String _dietLogKeyPrefix = 'local_diet_log_';

  /// Check if Firebase is available before making calls
  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _firestore {
    if (!_isFirebaseReady) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore unavailable: $e');
      return null;
    }
  }

  String? get _userId {
    if (!_isFirebaseReady) return null;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      debugPrint('Auth unavailable: $e');
      return null;
    }
  }

  // ──────────────────────────── User Profile ────────────────────────────

  /// Save or update user profile in Firestore
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db.collection('users').doc(uid).set(
        {
          ...profile,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return null;

    try {
      final doc = await db.collection('users').doc(uid).get().timeout(const Duration(seconds: 5));
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return null;
    }
  }

  /// Check if user has completed their profile
  Future<bool> isProfileCompleted() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return false;

    try {
      final doc = await db.collection('users').doc(uid).get().timeout(const Duration(seconds: 5));
      if (!doc.exists) return false;
      return (doc.data()?['profileCompleted'] as bool?) ?? false;
    } catch (e) {
      debugPrint('Error checking profile: $e');
      return false;
    }
  }

  /// Delete user profile
  Future<void> deleteUserProfile() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db.collection('users').doc(uid).delete().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error deleting profile: $e');
    }
  }

  // ──────────────────────────── Scan History ────────────────────────────

  /// Save a product scan to Firestore
  Future<void> saveScan(Map<String, dynamic> productData) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db
          .collection('scan_history')
          .doc(uid)
          .collection('scans')
          .add({
        ...productData,
        'scannedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving scan: $e');
    }
  }

  /// Get scan history from Firestore (most recent first)
  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 20}) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return [];

    try {
      final snapshot = await db
          .collection('scan_history')
          .doc(uid)
          .collection('scans')
          .orderBy('scannedAt', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 5));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error loading scan history: $e');
      return [];
    }
  }

  /// Delete a scan from history
  Future<void> deleteScan(String scanId) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db
          .collection('scan_history')
          .doc(uid)
          .collection('scans')
          .doc(scanId)
          .delete()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error deleting scan: $e');
    }
  }

  // ──────────────────────────── Products Cache ────────────────────────────

  /// Cache product data in Firestore (shared across users)
  Future<void> cacheProduct(
      String barcode, Map<String, dynamic> productData) async {
    final db = _firestore;
    if (db == null) return;

    try {
      await db.collection('products').doc(barcode).set(
        {
          ...productData,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error caching product: $e');
    }
  }

  /// Get cached product by barcode
  Future<Map<String, dynamic>?> getCachedProduct(String barcode) async {
    final db = _firestore;
    if (db == null) return null;

    try {
      final doc = await db.collection('products').doc(barcode).get().timeout(const Duration(seconds: 5));
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error loading cached product: $e');
      return null;
    }
  }

  // ──────────────────────────── Diet Log ────────────────────────────
  // Diet log entries are ALWAYS saved locally (SharedPreferences) as a fallback.
  // When Firebase is available, entries are ALSO saved to Firestore.
  // getDietLog merges both sources and deduplicates by entry name+time.

  /// Save a diet entry — always saves locally, also saves to Firestore if available.
  /// Returns true if saved to cloud, false if saved locally only.
  Future<bool> saveDietEntry(Map<String, dynamic> entryData) async {
    // Ensure 'time' field is always present for UI display
    final data = Map<String, dynamic>.from(entryData);
    if (!data.containsKey('time') || data['time'] == null) {
      final now = DateTime.now();
      data['time'] = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    // Ensure 'date' field is present
    if (!data.containsKey('date') || data['date'] == null) {
      final now = DateTime.now();
      data['date'] = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    // Remove any FieldValue entries that were added by the caller
    data.remove('timestamp');

    // Generate a local ID for this entry
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    data['id'] = localId;
    data['source'] = 'local';

    // 1. Always save locally first
    await _saveLocalDietEntry(data);
    debugPrint('Diet entry saved locally: ${data['name']}');

    // 2. Try to save to Firestore if available
    final db = _firestore;
    final uid = _userId;
    if (db != null && uid != null) {
      try {
        final firestoreData = Map<String, dynamic>.from(data);
        firestoreData.remove('id');
        firestoreData.remove('source');

        final docRef = await db
            .collection('diet_log')
            .doc(uid)
            .collection('entries')
            .add({
          ...firestoreData,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));

        // Update local entry with Firestore ID so we can match later
        data['firestoreId'] = docRef.id;
        data['source'] = 'synced';
        await _updateLocalDietEntry(data);
        debugPrint('Diet entry also saved to Firestore: ${docRef.id}');
        return true;
      } catch (e) {
        debugPrint('Firestore save failed (saved locally): $e');
      }
    }
    return false;
  }

  /// Get diet log for a specific date (YYYY-MM-DD).
  /// Returns merged results from Firestore + local storage.
  Future<List<Map<String, dynamic>>> getDietLog(String dateString) async {
    // 1. Always get local entries
    final localEntries = await _getLocalDietLog(dateString);

    // 2. Try to get Firestore entries
    final db = _firestore;
    final uid = _userId;
    List<Map<String, dynamic>> firestoreEntries = [];

    if (db != null && uid != null) {
      try {
        try {
          final snapshot = await db
              .collection('diet_log')
              .doc(uid)
              .collection('entries')
              .where('date', isEqualTo: dateString)
              .orderBy('createdAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 5));

          firestoreEntries = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['source'] = 'cloud';
            return data;
          }).toList();
        } catch (indexError) {
          // Fallback: query without orderBy (works without composite index)
          debugPrint('Composite index not ready, using fallback: $indexError');
          final snapshot = await db
              .collection('diet_log')
              .doc(uid)
              .collection('entries')
              .where('date', isEqualTo: dateString)
              .get()
              .timeout(const Duration(seconds: 5));

          firestoreEntries = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['source'] = 'cloud';
            return data;
          }).toList();
        }
      } catch (e) {
        debugPrint('Firestore diet log failed, using local only: $e');
      }
    }

    // 3. Merge & deduplicate (prefer Firestore entries over local synced ones)
    final Set<String> firestoreIds = firestoreEntries
        .map((e) => e['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final List<Map<String, dynamic>> merged = [...firestoreEntries];

    for (var local in localEntries) {
      final firestoreId = local['firestoreId'] as String?;
      // Skip local entries that are already represented in Firestore results
      if (firestoreId != null && firestoreIds.contains(firestoreId)) {
        continue;
      }
      merged.add(local);
    }

    // Sort by time descending
    merged.sort((a, b) {
      final aTime = a['time'] as String? ?? '';
      final bTime = b['time'] as String? ?? '';
      return bTime.compareTo(aTime);
    });

    return merged;
  }

  /// Delete a diet entry from both Firestore and local storage
  Future<void> deleteDietEntry(String entryId) async {
    // Delete from local storage
    await _deleteLocalDietEntry(entryId);

    // Delete from Firestore if available
    final db = _firestore;
    final uid = _userId;
    if (db != null && uid != null) {
      try {
        // entryId might be a local ID or a Firestore ID
        if (!entryId.startsWith('local_')) {
          await db
              .collection('diet_log')
              .doc(uid)
              .collection('entries')
              .doc(entryId)
              .delete()
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('Error deleting diet entry from Firestore: $e');
      }
    }
  }

  // ──────────────────────────── Shopping List ────────────────────────────

  /// Add an item to the shopping list
  Future<void> addShoppingItem(Map<String, dynamic> itemData) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db
          .collection('shopping_list')
          .doc(uid)
          .collection('items')
          .add({
        ...itemData,
        'checked': false,
        'addedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error adding shopping item: $e');
    }
  }

  /// Get all shopping list items
  Future<List<Map<String, dynamic>>> getShoppingList() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return [];

    try {
      final snapshot = await db
          .collection('shopping_list')
          .doc(uid)
          .collection('items')
          .orderBy('addedAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 5));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error loading shopping list: $e');
      return [];
    }
  }

  /// Toggle shopping item checked state
  Future<void> toggleShoppingItem(String itemId, bool checked) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db
          .collection('shopping_list')
          .doc(uid)
          .collection('items')
          .doc(itemId)
          .update({'checked': checked})
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error toggling shopping item: $e');
    }
  }

  /// Delete a shopping list item
  Future<void> deleteShoppingItem(String itemId) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db
          .collection('shopping_list')
          .doc(uid)
          .collection('items')
          .doc(itemId)
          .delete()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error deleting shopping item: $e');
    }
  }

  /// Clear all checked items in shopping list
  Future<void> clearCheckedShoppingItems() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      final snapshot = await db
          .collection('shopping_list')
          .doc(uid)
          .collection('items')
          .where('checked', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 5));

      final batch = db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error clearing shopping items: $e');
    }
  }

  // ──────────────── Local Diet Log Helpers (SharedPreferences) ────────────────

  /// Save a diet entry to local storage
  Future<void> _saveLocalDietEntry(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '$_dietLogKeyPrefix${entry['date']}';
      final existingJson = prefs.getString(dateKey);
      List<Map<String, dynamic>> entries = [];

      if (existingJson != null) {
        final decoded = jsonDecode(existingJson) as List;
        entries = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      entries.add(entry);
      await prefs.setString(dateKey, jsonEncode(entries));
    } catch (e) {
      debugPrint('Error saving local diet entry: $e');
    }
  }

  /// Update a local diet entry (e.g., after syncing to Firestore)
  Future<void> _updateLocalDietEntry(Map<String, dynamic> updatedEntry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '$_dietLogKeyPrefix${updatedEntry['date']}';
      final existingJson = prefs.getString(dateKey);
      if (existingJson == null) return;

      final decoded = jsonDecode(existingJson) as List;
      final entries = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final idx = entries.indexWhere((e) => e['id'] == updatedEntry['id']);
      if (idx != -1) {
        entries[idx] = updatedEntry;
        await prefs.setString(dateKey, jsonEncode(entries));
      }
    } catch (e) {
      debugPrint('Error updating local diet entry: $e');
    }
  }

  /// Get local diet entries for a specific date
  Future<List<Map<String, dynamic>>> _getLocalDietLog(String dateString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '$_dietLogKeyPrefix$dateString';
      final json = prefs.getString(dateKey);
      if (json == null) return [];

      final decoded = jsonDecode(json) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading local diet log: $e');
      return [];
    }
  }

  /// Delete a local diet entry by ID
  Future<void> _deleteLocalDietEntry(String entryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // We need to scan all date keys since we might not know the date
      final keys = prefs.getKeys().where((k) => k.startsWith(_dietLogKeyPrefix));

      for (final key in keys) {
        final json = prefs.getString(key);
        if (json == null) continue;

        final decoded = jsonDecode(json) as List;
        final entries = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final originalLength = entries.length;

        // Remove by local ID or by firestoreId
        entries.removeWhere((e) =>
            e['id'] == entryId || e['firestoreId'] == entryId);

        if (entries.length != originalLength) {
          if (entries.isEmpty) {
            await prefs.remove(key);
          } else {
            await prefs.setString(key, jsonEncode(entries));
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error deleting local diet entry: $e');
    }
  }

  /// Sync any unsynced local diet entries to Firestore.
  /// Call this when Firebase becomes available.
  Future<void> syncLocalEntriesToCloud() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_dietLogKeyPrefix));

      for (final key in keys) {
        final json = prefs.getString(key);
        if (json == null) continue;

        final decoded = jsonDecode(json) as List;
        final entries = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        bool updated = false;

        for (int i = 0; i < entries.length; i++) {
          if (entries[i]['source'] == 'local') {
            try {
              final firestoreData = Map<String, dynamic>.from(entries[i]);
              firestoreData.remove('id');
              firestoreData.remove('source');
              firestoreData.remove('firestoreId');

              final docRef = await db
                  .collection('diet_log')
                  .doc(uid)
                  .collection('entries')
                  .add({
                ...firestoreData,
                'createdAt': FieldValue.serverTimestamp(),
              }).timeout(const Duration(seconds: 5));

              entries[i]['firestoreId'] = docRef.id;
              entries[i]['source'] = 'synced';
              updated = true;
              debugPrint('Synced local entry to cloud: ${entries[i]['name']}');
            } catch (e) {
              debugPrint('Failed to sync entry: $e');
            }
          }
        }

        if (updated) {
          await prefs.setString(key, jsonEncode(entries));
        }
      }
    } catch (e) {
      debugPrint('Error syncing local entries: $e');
    }
  }
}
