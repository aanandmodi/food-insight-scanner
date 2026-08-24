// lib/services/firestore_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/data_refresh_bus.dart';
import 'local_database_service.dart';

/// Outcome of a profile read that distinguishes three cases the old nullable
/// return conflated:
///  * [data] non-null            → a profile was found.
///  * [data] null, [failed] false → no profile exists (a genuinely new user).
///  * [data] null, [failed] true  → the read failed (offline/timeout); the
///    caller must NOT treat this as a new user or it will clobber the real
///    cloud profile / force re-onboarding.
class ProfileLoadResult {
  final Map<String, dynamic>? data;
  final bool failed;

  const ProfileLoadResult.found(Map<String, dynamic> this.data) : failed = false;
  const ProfileLoadResult.absent()
      : data = null,
        failed = false;
  const ProfileLoadResult.failed()
      : data = null,
        failed = true;

  bool get exists => data != null;
}

/// Service for managing user data in Firestore.
/// All methods are resilient to Firebase being unavailable (offline mode).
/// Diet log entries use SQLite (via [LocalDatabaseService]) as the local
/// fallback instead of SharedPreferences.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();

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

  // ──────────────────────────── Live Streams ────────────────────────────

  /// Re-subscribes to [mapper]'s stream every time [source] emits, cancelling
  /// the previous inner subscription.
  ///
  /// This replaces the previous `await for (user) { yield* snapshots() }`
  /// pattern, which deadlocked: `yield*` of an infinite stream never completes,
  /// so the outer loop could never observe a second auth event and the query
  /// stayed bound to the first signed-in user forever (leaking one account's
  /// data into the next session).
  static Stream<R> _switchMap<T, R>(
    Stream<T> source,
    Stream<R> Function(T value) mapper,
  ) {
    StreamSubscription<T>? outer;
    StreamSubscription<R>? inner;
    late final StreamController<R> controller;

    void dropInner() {
      inner?.cancel();
      inner = null;
    }

    controller = StreamController<R>(
      onListen: () {
        outer = source.listen(
          (value) {
            dropInner();
            inner = mapper(value).listen(
              controller.add,
              onError: controller.addError,
            );
          },
          onError: controller.addError,
          onDone: () {
            dropInner();
            controller.close();
          },
        );
      },
      onCancel: () async {
        await outer?.cancel();
        dropInner();
      },
    );

    return controller.stream;
  }

  /// Emits once per *change of user*, so switching accounts re-runs queries but
  /// token refreshes for the same user do not.
  Stream<User?> get _userChanges => FirebaseAuth.instance
      .authStateChanges()
      .distinct((a, b) => a?.uid == b?.uid);

  static List<Map<String, dynamic>> _docsToMaps(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Live stream of scan history (most recent first). Responds to auth changes.
  Stream<List<Map<String, dynamic>>> scanHistoryStream({int limit = 50}) {
    return _switchMap<User?, List<Map<String, dynamic>>>(_userChanges, (user) {
      if (user == null || !_isFirebaseReady) {
        return Stream.value(const <Map<String, dynamic>>[]);
      }
      return FirebaseFirestore.instance
          .collection('scan_history')
          .doc(user.uid)
          .collection('scans')
          .orderBy('scannedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(_docsToMaps)
          .handleError((Object e) {
        debugPrint('scanHistoryStream error: $e');
      });
    });
  }

  /// Live stream of shopping list items (most recent first).
  Stream<List<Map<String, dynamic>>> shoppingListStream() {
    return _switchMap<User?, List<Map<String, dynamic>>>(_userChanges, (user) {
      if (user == null || !_isFirebaseReady) {
        return Stream.value(const <Map<String, dynamic>>[]);
      }
      return FirebaseFirestore.instance
          .collection('shopping_list')
          .doc(user.uid)
          .collection('items')
          .orderBy('addedAt', descending: true)
          .snapshots()
          .map(_docsToMaps)
          .handleError((Object e) {
        debugPrint('shoppingListStream error: $e');
      });
    });
  }

  /// Live stream of the current user's diet-log entries for [dateString].
  Stream<List<Map<String, dynamic>>> dietLogStream(String dateString) {
    return _switchMap<User?, List<Map<String, dynamic>>>(_userChanges, (user) {
      if (user == null || !_isFirebaseReady) {
        return Stream.value(const <Map<String, dynamic>>[]);
      }
      return FirebaseFirestore.instance
          .collection('diet_log')
          .doc(user.uid)
          .collection('entries')
          .where('date', isEqualTo: dateString)
          .snapshots()
          .map(_docsToMaps)
          .handleError((Object e) {
        debugPrint('dietLogStream error: $e');
      });
    });
  }

  // ──────────────────────────── User Profile ────────────────────────────

  /// Save or update user profile in Firestore.
  /// Returns true when the write reached the cloud.
  Future<bool> saveUserProfile(Map<String, dynamic> profile) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) {
      debugPrint('saveUserProfile skipped: no Firebase/uid');
      return false;
    }

    try {
      await db.collection('users').doc(uid).set(
        {
          ...profile,
          'uid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      return false;
    }
  }

  /// Get user profile from Firestore, falling back to SharedPreferences.
  ///
  /// Returns null when no profile exists anywhere. The previous version always
  /// returned a map — even when every value inside it was null — so callers saw
  /// a non-empty "profile" for brand-new users and skipped onboarding.
  ///
  /// Prefer [loadUserProfile] when the caller needs to tell "this user has no
  /// profile" apart from "we could not read it" — this shape cannot express the
  /// difference and reports both as null.
  Future<Map<String, dynamic>?> getUserProfile() async =>
      (await loadUserProfile()).data;

  /// Profile read that distinguishes an absent document from a failed read.
  ///
  /// Callers that treat null as "brand-new user" would otherwise overwrite a
  /// real cloud profile, or force a returning user back through onboarding,
  /// whenever Firestore merely timed out.
  Future<ProfileLoadResult> loadUserProfile() async {
    final db = _firestore;
    final uid = _userId;

    // Distinguishes "Firestore said this user has no document" from "we never
    // got an answer". Only the former is safe to treat as a new user.
    var cloudReadFailed = false;

    if (db != null && uid != null) {
      try {
        final doc = await db
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists && doc.data() != null) {
          return ProfileLoadResult.found(doc.data()!);
        }
      } catch (e) {
        cloudReadFailed = true;
        debugPrint('Error loading user profile: $e');
      }
    } else if (uid != null) {
      // Signed in but Firestore is unreachable — absence proves nothing.
      cloudReadFailed = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name');
      // Name is the one field onboarding always writes. Without it there is no
      // local profile to fall back to.
      if (name == null || name.trim().isEmpty) {
        return cloudReadFailed
            ? const ProfileLoadResult.failed()
            : const ProfileLoadResult.absent();
      }

      return ProfileLoadResult.found({
        'name': name,
        'email': prefs.getString('user_email'),
        'photoUrl': prefs.getString('user_photoUrl'),
        'gender': prefs.getString('user_gender'),
        'age': prefs.getInt('user_age'),
        'dateOfBirth': prefs.getString('user_dob'),
        'heightCm': prefs.getDouble('user_height'),
        'weightKg': prefs.getDouble('user_weight'),
        'healthGoals': prefs.getString('user_health_goal'),
        'activityLevel': prefs.getString('user_activity_level'),
        'allergies': prefs.getStringList('user_allergies') ?? const [],
        'dietaryPreferences':
            prefs.getStringList('user_dietary_preferences') ?? const [],
        'diseases': prefs.getStringList('user_diseases') ?? const [],
        'profileCompleted': prefs.getBool('profile_completed') ?? false,
      });
    } catch (e) {
      debugPrint('Error loading profile from SharedPreferences: $e');
      return const ProfileLoadResult.failed();
    }
  }

  /// Check if user has completed their profile
  Future<bool> isProfileCompleted() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return false;

    try {
      final doc = await db.collection('users').doc(uid).get();
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
      await db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting profile: $e');
    }
  }

  // ──────────────────────────── Scan History ────────────────────────────

  /// Save a product scan to Firestore. Returns true when the write succeeded.
  ///
  /// Keyed by barcode so re-scanning a product updates one document instead of
  /// appending an unbounded stream of near-identical rows.
  Future<bool> saveScan(Map<String, dynamic> productData) async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return false;

    try {
      final scans =
          db.collection('scan_history').doc(uid).collection('scans');
      final payload = {
        ...productData,
        'scannedAt': FieldValue.serverTimestamp(),
      };

      final barcode = (productData['barcode'] as String? ?? '').trim();
      if (barcode.isEmpty) {
        await scans.add(payload);
      } else {
        await scans.doc(barcode).set(payload, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      debugPrint('Error saving scan: $e');
      return false;
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
          ;

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
          ;
    } catch (e) {
      debugPrint('Error deleting scan: $e');
    }
  }

  // ──────────────────────────── Diet Log ────────────────────────────
  // Diet log entries are saved locally to SQLite (via LocalDatabaseService)
  // and synced to Firestore when available.

  /// Save a diet entry. This is the **single** write path for diet entries: it
  /// always inserts one SQLite row and, when possible, one Firestore document.
  ///
  /// Callers must NOT also call `LocalDatabaseService.insertDietEntry` — doing
  /// so was creating two local rows per meal and double-counting calories.
  ///
  /// Returns true if it also reached the cloud, false if local-only.
  Future<bool> saveDietEntry(Map<String, dynamic> entryData) async {
    // Ensure 'time' field is always present for UI display
    final data = Map<String, dynamic>.from(entryData);
    if (data['time'] == null) {
      final now = DateTime.now();
      data['time'] =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    // Ensure 'date' field is present
    if (data['date'] == null) {
      final now = DateTime.now();
      data['date'] =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    // Strip any Firestore sentinels the caller may have added — they cannot be
    // bound to SQLite or re-encoded as JSON.
    data.remove('timestamp');
    data.remove('createdAt');

    // Generate a local ID for this entry (microseconds: two meals logged in the
    // same millisecond used to collide).
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    data['id'] = localId;
    data['source'] = 'local';

    // 1. Always save locally first (SQLite)
    final localRow = await _localDb.insertDietEntry(data);
    if (localRow <= 0) {
      debugPrint('WARNING: diet entry "${data['name']}" failed to save locally');
    } else {
      debugPrint('Diet entry saved to SQLite: ${data['name']}');
    }

    // 2. Try to save to Firestore if available
    final db = _firestore;
    final uid = _userId;
    bool cloudOk = false;
    if (db != null && uid != null) {
      try {
        final firestoreData = Map<String, dynamic>.from(data);
        firestoreData.remove('id');
        firestoreData.remove('source');

        // Pre-allocate the document id CLIENT-SIDE and record it locally before
        // the network write. The previous order (add() -> markDietEntrySynced)
        // was a non-atomic two-step commit: if the process died in between, the
        // cloud doc existed while the local row still had firestore_id = NULL,
        // so getDietLog's dedup could not match them and the meal was listed —
        // and re-uploaded — twice, double-counting its calories forever.
        final docRef =
            db.collection('diet_log').doc(uid).collection('entries').doc();
        await _localDb.markDietEntrySynced(localId, docRef.id);

        // A bounded write: an un-timed-out await here left the caller's spinner
        // up indefinitely on a flaky connection, and users re-tapped Save and
        // inserted duplicate rows. Firestore keeps its own offline queue, so on
        // timeout the write still lands later — we just stop blocking the UI.
        await docRef.set({
          ...firestoreData,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 10));

        debugPrint('Diet entry also saved to Firestore: ${docRef.id}');
        cloudOk = true;
      } on TimeoutException {
        // Queued locally by Firestore and already marked synced above, so it
        // will reconcile on reconnect rather than being uploaded a second time.
        debugPrint('Firestore save timed out — queued for retry');
      } catch (e) {
        debugPrint('Firestore save failed (saved locally): $e');
      }
    }

    // Tell the dashboard / diet log to reload.
    DataRefreshBus.dietLogChanged();
    return cloudOk;
  }

  /// Get diet log for a specific date (YYYY-MM-DD).
  /// Returns merged results from Firestore + local SQLite.
  Future<List<Map<String, dynamic>>> getDietLog(String dateString) async {
    // 1. Always get local entries from SQLite
    final localEntries = await _localDb.getDietLogByDate(dateString);

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
              ;

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
              ;

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

    // 4. Mirror cloud-only entries into SQLite so they survive going offline
    // (e.g. logged on another device). Idempotent — keyed on the Firestore id.
    for (final entry in firestoreEntries) {
      final id = entry['id'] as String? ?? '';
      if (id.isEmpty) continue;
      try {
        if (await _localDb.dietEntryExists(id)) continue;
        await _localDb.insertDietEntry({
          ...entry,
          'id': id,
          'firestoreId': id,
          'source': 'synced',
        });
      } catch (e) {
        debugPrint('Could not mirror cloud diet entry $id locally: $e');
      }
    }

    // Sort by time descending
    merged.sort((a, b) {
      final aTime = a['time'] as String? ?? '';
      final bTime = b['time'] as String? ?? '';
      return bTime.compareTo(aTime);
    });

    return merged;
  }

  /// Delete a diet entry from both Firestore and local SQLite
  Future<void> deleteDietEntry(String entryId) async {
    if (entryId.trim().isEmpty) {
      debugPrint('deleteDietEntry called with an empty id — ignoring');
      return;
    }

    // Resolve the cloud document id BEFORE deleting the local row, because that
    // row holds the only local_id -> firestore_id mapping.
    //
    // The previous `!entryId.startsWith('local_')` test was a broken heuristic:
    // a *synced* entry is handed to the UI with id = 'local_…' (its local id)
    // plus a separate firestoreId, so deleting one skipped the cloud delete
    // entirely. The orphaned document was then re-downloaded by getDietLog's
    // mirror step and the "deleted" meal reappeared on the next refresh.
    final resolvedCloudId = await _localDb.getDietEntryFirestoreId(entryId);
    // If the id is not a local_ id it is itself a Firestore doc id (that is how
    // cloud-sourced entries are surfaced), so fall back to it.
    final cloudId = resolvedCloudId ??
        (entryId.startsWith('local_') ? null : entryId);

    // Delete from local SQLite
    await _localDb.deleteDietEntry(entryId);

    // Delete from Firestore if available
    final db = _firestore;
    final uid = _userId;
    if (db != null && uid != null && cloudId != null) {
      try {
        await db
            .collection('diet_log')
            .doc(uid)
            .collection('entries')
            .doc(cloudId)
            .delete()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Firestore queues the delete offline, so this still converges.
        debugPrint('Error deleting diet entry from Firestore: $e');
      }
    }

    DataRefreshBus.dietLogChanged();
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
      });
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
          ;

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
          ;
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
          ;
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
          ;

      final batch = db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing shopping items: $e');
    }
  }

  // ──────────────────────── Sync Helpers ────────────────────────

  /// Sync any unsynced local diet entries to Firestore.
  /// Call this when Firebase becomes available.
  Future<void> syncLocalEntriesToCloud() async {
    final db = _firestore;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      final unsyncedEntries = await _localDb.getUnsyncedDietEntries();

      for (final entry in unsyncedEntries) {
        try {
          final firestoreData = Map<String, dynamic>.from(entry);
          final localId = firestoreData['id'] as String?;
          firestoreData.remove('id');
          firestoreData.remove('source');
          firestoreData.remove('firestoreId');

          // Same atomic pattern as saveDietEntry: pre-allocate the id and mark
          // the local row synced BEFORE the write, so a crash mid-flush can
          // never leave an unlinked cloud doc that this loop would re-upload
          // (Firestore durably queues the set() and lands it on reconnect).
          final docRef = db
              .collection('diet_log')
              .doc(uid)
              .collection('entries')
              .doc();

          if (localId != null) {
            await _localDb.markDietEntrySynced(localId, docRef.id);
          }

          await docRef.set({
            ...firestoreData,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Synced local entry to cloud: ${entry['name']}');
        } catch (e) {
          debugPrint('Failed to sync entry: $e');
        }
      }
    } catch (e) {
      debugPrint('Error syncing local entries: $e');
    }
  }
}
