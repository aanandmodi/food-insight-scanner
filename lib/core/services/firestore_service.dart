// lib/core/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user data and scan history in Firestore.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ──────────────────────────── User Profile ────────────────────────────

  /// Save or update user profile in Firestore
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    if (_userId == null) return;
    await _firestore.collection('users').doc(_userId).set(
      {
        ...profile,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_userId == null) return null;
    final doc = await _firestore.collection('users').doc(_userId).get();
    return doc.exists ? doc.data() : null;
  }

  // ──────────────────────────── Scan History ────────────────────────────

  /// Save a product scan to Firestore
  Future<void> saveScan(Map<String, dynamic> productData) async {
    if (_userId == null) return;
    await _firestore
        .collection('scan_history')
        .doc(_userId)
        .collection('scans')
        .add({
      ...productData,
      'scannedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get scan history from Firestore (most recent first)
  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 20}) async {
    if (_userId == null) return [];
    final snapshot = await _firestore
        .collection('scan_history')
        .doc(_userId)
        .collection('scans')
        .orderBy('scannedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Delete a scan from history
  Future<void> deleteScan(String scanId) async {
    if (_userId == null) return;
    await _firestore
        .collection('scan_history')
        .doc(_userId)
        .collection('scans')
        .doc(scanId)
        .delete();
  }

  // ──────────────────────────── Products Cache ────────────────────────────

  /// Cache product data in Firestore (shared across users)
  Future<void> cacheProduct(
      String barcode, Map<String, dynamic> productData) async {
    await _firestore.collection('products').doc(barcode).set(
      {
        ...productData,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Get cached product by barcode
  Future<Map<String, dynamic>?> getCachedProduct(String barcode) async {
    final doc = await _firestore.collection('products').doc(barcode).get();
    return doc.exists ? doc.data() : null;
  }

  // ──────────────────────────── Diet Log ────────────────────────────

  /// Save a diet entry (meal) to Firestore
  Future<void> saveDietEntry(Map<String, dynamic> entryData) async {
    if (_userId == null) return;
    
    // Ensure date is stored as a Timestamp for querying
    // We expect entryData to have 'date' as a string or DateTime object
    // but Firestore works best with Timestamps.
    // For simplicity, we just add the server timestamp as 'createdAt'.
    // The UI should provide a 'dateString' (YYYY-MM-DD) for easy filtering.
    
    await _firestore
        .collection('diet_log')
        .doc(_userId)
        .collection('entries')
        .add({
      ...entryData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get diet log for a specific date (YYYY-MM-DD)
  Future<List<Map<String, dynamic>>> getDietLog(String dateString) async {
    if (_userId == null) return [];
    
    final snapshot = await _firestore
        .collection('diet_log')
        .doc(_userId)
        .collection('entries')
        .where('date', isEqualTo: dateString)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
  
  /// Delete a diet entry
  Future<void> deleteDietEntry(String entryId) async {
    if (_userId == null) return;
    await _firestore
        .collection('diet_log')
        .doc(_userId)
        .collection('entries')
        .doc(entryId)
        .delete();
  }
}
