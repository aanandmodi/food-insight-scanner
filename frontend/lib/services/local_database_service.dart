// lib/services/local_database_service.dart

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Sentinel uid used for rows written before the user signed in (guest/offline).
/// [LocalDatabaseService.adoptLocalRows] reassigns them once a uid is known.
const String kLocalUid = '__local__';

/// Service for efficient local persistence using SQLite.
///
/// Every row is scoped to a `user_id` so two accounts on the same device can
/// never see each other's data, even if a sign-out purge is interrupted.
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;

  /// Current owner for reads/writes. Falls back to [kLocalUid] when Firebase
  /// is unavailable or nobody is signed in.
  String get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? kLocalUid;
    } catch (_) {
      return kLocalUid;
    }
  }

  /// Rows readable by the current session: the signed-in user's rows plus any
  /// rows captured before sign-in that have not been adopted yet.
  List<String> get _readableUids =>
      _uid == kLocalUid ? [kLocalUid] : [_uid, kLocalUid];

  /// Initialise the database. Call once from `main()`.
  Future<void> initialize() async {
    if (_db != null && _db!.isOpen) return;

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'nutricore.db');

      _db = await openDatabase(
        path,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      debugPrint('LocalDatabaseService initialised at $path');
    } catch (e) {
      debugPrint('Error in LocalDatabaseService initialize: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diet_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL DEFAULT '$kLocalUid',
        local_id TEXT NOT NULL,
        firestore_id TEXT,
        name TEXT NOT NULL,
        meal_type TEXT,
        calories INTEGER DEFAULT 0,
        protein REAL DEFAULT 0,
        sugar REAL DEFAULT 0,
        fat REAL DEFAULT 0,
        carbs REAL DEFAULT 0,
        brand TEXT,
        time TEXT,
        date TEXT NOT NULL,
        sync_status TEXT DEFAULT 'local',
        extra_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL DEFAULT '$kLocalUid',
        barcode TEXT NOT NULL,
        name TEXT,
        brand TEXT,
        category TEXT,
        image_url TEXT,
        nutrition_json TEXT,
        ingredients_json TEXT,
        allergens_json TEXT,
        serving_size TEXT,
        nutriscore TEXT,
        nova_group INTEGER,
        quantity TEXT,
        ai_analysis TEXT,
        scanned_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL DEFAULT '$kLocalUid',
        local_id TEXT NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT,
        checked INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_diet_log_date ON diet_log(user_id, date)');
    await db.execute(
        'CREATE INDEX idx_scan_history_barcode ON scan_history(user_id, barcode)');
    await db.execute(
        'CREATE INDEX idx_shopping_list_user ON shopping_list(user_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shopping_list (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          local_id TEXT NOT NULL,
          name TEXT NOT NULL,
          brand TEXT,
          category TEXT,
          checked INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add per-user scoping. Existing rows belong to whoever was signed in on
      // this device, which we cannot know retroactively — park them under the
      // local sentinel so the next sign-in adopts them rather than losing them.
      for (final table in ['diet_log', 'scan_history', 'shopping_list']) {
        try {
          await db.execute(
              "ALTER TABLE $table ADD COLUMN user_id TEXT NOT NULL DEFAULT '$kLocalUid'");
        } catch (e) {
          debugPrint('Migration v3: $table user_id column already present ($e)');
        }
      }
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_diet_log_date ON diet_log(user_id, date)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_scan_history_barcode ON scan_history(user_id, barcode)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_shopping_list_user ON shopping_list(user_id)');
    }
  }

  Future<Database?> get _database async {
    if (_db == null || !_db!.isOpen) {
      await initialize();
    }
    return _db;
  }

  // ──────────────────────────── Value sanitising ────────────────────────────

  /// Coerce an arbitrary value into something sqflite can bind.
  ///
  /// sqflite only accepts `null`, `num`, `String` and `Uint8List`. Passing a
  /// `Map`, `List`, `DateTime` or a Firestore `FieldValue` sentinel throws at
  /// runtime, which is what previously made every AI-analysed scan and every
  /// AI-logged meal fail to persist.
  static Object? _bind(Object? value) {
    if (value == null || value is num || value is String) return value;
    if (value is bool) return value ? 1 : 0;
    if (value is DateTime) return value.toIso8601String();
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return jsonEncode(_jsonSafe(value));
      }
    }
    return value.toString();
  }

  /// Recursively replace values `jsonEncode` cannot handle (Firestore
  /// sentinels, `Timestamp`, custom objects) with encodable equivalents.
  static Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
    }
    if (value is List) return value.map(_jsonSafe).toList();
    // FieldValue.serverTimestamp(), Timestamp, DocumentReference, …
    return value.toString();
  }

  static String _encodeSafe(Object? value) {
    try {
      return jsonEncode(_jsonSafe(value));
    } catch (e) {
      debugPrint('Could not encode value for extra_json: $e');
      return '{}';
    }
  }

  /// Reassign guest/offline rows to a real uid after sign-in so nothing the
  /// user logged before authenticating is orphaned.
  Future<void> adoptLocalRows(String uid) async {
    if (uid.isEmpty || uid == kLocalUid) return;
    final db = await _database;
    if (db == null) return;

    for (final table in ['diet_log', 'scan_history', 'shopping_list']) {
      try {
        final n = await db.update(
          table,
          {'user_id': uid},
          where: 'user_id = ?',
          whereArgs: [kLocalUid],
        );
        if (n > 0) debugPrint('Adopted $n pre-sign-in row(s) in $table for $uid');
      } catch (e) {
        debugPrint('Error adopting rows in $table: $e');
      }
    }
  }

  // ──────────────────────────── Diet Log ────────────────────────────

  /// Insert a diet entry. Returns the row id, or -1 on failure.
  Future<int> insertDietEntry(Map<String, dynamic> entry) async {
    final db = await _database;
    if (db == null) return -1;

    final localId = entry['id'] as String? ??
        'local_${DateTime.now().microsecondsSinceEpoch}';

    try {
      return await db.insert('diet_log', {
        'user_id': _uid,
        'local_id': localId,
        'firestore_id': _bind(entry['firestoreId']),
        'name': entry['name'] as String? ?? 'Unknown',
        'meal_type': _bind(entry['mealType']),
        'calories': (entry['calories'] as num?)?.toInt() ?? 0,
        'protein': (entry['protein'] as num?)?.toDouble() ?? 0,
        'sugar': (entry['sugar'] as num?)?.toDouble() ?? 0,
        'fat': (entry['fat'] as num?)?.toDouble() ?? 0,
        'carbs': (entry['carbs'] as num?)?.toDouble() ?? 0,
        'brand': _bind(entry['brand']),
        'time': _bind(entry['time']),
        'date': _bind(entry['date']) ?? '',
        'sync_status': entry['source'] as String? ?? 'local',
        'extra_json': _encodeSafe(entry),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error inserting diet entry: $e');
      return -1;
    }
  }

  /// True when an entry with this local_id or firestore_id already exists for
  /// the current user. Used to keep the cloud→local mirror idempotent.
  Future<bool> dietEntryExists(String id) async {
    if (id.isEmpty) return false;
    final db = await _database;
    if (db == null) return false;

    final uids = _readableUids;
    final rows = await db.query(
      'diet_log',
      columns: ['id'],
      where:
          '(local_id = ? OR firestore_id = ?) AND user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: [id, id, ...uids],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Update the Firestore ID and sync status after cloud save.
  Future<void> markDietEntrySynced(String localId, String firestoreId) async {
    final db = await _database;
    if (db == null) return;

    await db.update(
      'diet_log',
      {'firestore_id': firestoreId, 'sync_status': 'synced'},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Get diet entries for a specific date (YYYY-MM-DD).
  Future<List<Map<String, dynamic>>> getDietLogByDate(String dateString) async {
    final db = await _database;
    if (db == null) return [];

    try {
      final uids = _readableUids;
      final rows = await db.query(
        'diet_log',
        where:
            'date = ? AND user_id IN (${List.filled(uids.length, '?').join(',')})',
        whereArgs: [dateString, ...uids],
        orderBy: 'time DESC',
      );

      return rows.map(_rowToDietEntry).toList();
    } catch (e) {
      debugPrint('Error getting diet log by date: $e');
      return [];
    }
  }

  /// Total calories per day over the last [days] days, for the trend chart.
  /// Returns a map of `yyyy-MM-dd` → total kcal.
  Future<Map<String, int>> getDailyCalorieTotals({int days = 7}) async {
    final db = await _database;
    if (db == null) return {};

    try {
      final uids = _readableUids;
      final rows = await db.rawQuery(
        'SELECT date, SUM(calories) AS total FROM diet_log '
        'WHERE user_id IN (${List.filled(uids.length, '?').join(',')}) '
        'GROUP BY date ORDER BY date DESC LIMIT ?',
        [...uids, days],
      );
      return {
        for (final r in rows)
          (r['date'] as String? ?? ''): (r['total'] as num?)?.toInt() ?? 0,
      }..remove('');
    } catch (e) {
      debugPrint('Error computing daily calorie totals: $e');
      return {};
    }
  }

  /// Resolve the Firestore document id for an entry addressed by either its
  /// `local_id` or its `firestore_id`.
  ///
  /// Needed because a *synced* entry is surfaced to the UI with `id` =
  /// `local_…` (see [_rowToDietEntry]) while its cloud document is named by
  /// `firestore_id`. Callers deleting an entry must resolve this **before**
  /// removing the local row, since that row holds the only mapping between the
  /// two ids. Returns null for entries that were never uploaded.
  Future<String?> getDietEntryFirestoreId(String entryId) async {
    if (entryId.trim().isEmpty) return null;
    final db = await _database;
    if (db == null) return null;

    try {
      final uids = _readableUids;
      final rows = await db.query(
        'diet_log',
        columns: ['firestore_id'],
        where:
            '(local_id = ? OR firestore_id = ?) AND user_id IN (${List.filled(uids.length, '?').join(',')})',
        whereArgs: [entryId, entryId, ...uids],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final id = rows.first['firestore_id'] as String?;
      return (id == null || id.isEmpty) ? null : id;
    } catch (e) {
      debugPrint('Error resolving firestore id for $entryId: $e');
      return null;
    }
  }

  /// Delete a diet entry by its local_id or firestore_id.
  Future<void> deleteDietEntry(String entryId) async {
    if (entryId.trim().isEmpty) return;
    final db = await _database;
    if (db == null) return;

    final uids = _readableUids;
    final deleted = await db.delete(
      'diet_log',
      where:
          '(local_id = ? OR firestore_id = ?) AND user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: [entryId, entryId, ...uids],
    );
    debugPrint('Deleted $deleted diet entry row(s) for id=$entryId');
  }

  /// Get all unsynced diet entries (for cloud sync on reconnect).
  Future<List<Map<String, dynamic>>> getUnsyncedDietEntries() async {
    final db = await _database;
    if (db == null) return [];

    final uids = _readableUids;
    final rows = await db.query(
      'diet_log',
      where:
          "sync_status = 'local' AND user_id IN (${List.filled(uids.length, '?').join(',')})",
      whereArgs: uids,
    );
    return rows.map(_rowToDietEntry).toList();
  }

  Map<String, dynamic> _rowToDietEntry(Map<String, dynamic> row) {
    return {
      'id': row['local_id'] ?? row['firestore_id'] ?? row['id'].toString(),
      'firestoreId': row['firestore_id'],
      'name': row['name'],
      'mealType': row['meal_type'],
      'calories': row['calories'],
      'protein': row['protein'],
      'sugar': row['sugar'],
      'fat': row['fat'],
      'carbs': row['carbs'],
      'brand': row['brand'],
      'time': row['time'],
      'date': row['date'],
      'source': row['sync_status'],
    };
  }

  // ──────────────────────────── Shopping List ────────────────────────────

  Future<List<Map<String, dynamic>>> getShoppingList() async {
    final db = await _database;
    if (db == null) return [];

    final uids = _readableUids;
    final rows = await db.query(
      'shopping_list',
      where: 'user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: uids,
      orderBy: 'created_at DESC',
    );
    return rows
        .map((r) => {
              'id': r['local_id'],
              'name': r['name'],
              'brand': r['brand'] ?? '',
              'category': r['category'] ?? 'General',
              'checked': r['checked'] == 1,
              'createdAt': r['created_at'],
            })
        .toList();
  }

  Future<void> addShoppingItem(Map<String, dynamic> item) async {
    final db = await _database;
    if (db == null) return;

    final localId = 'shop_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('shopping_list', {
      'user_id': _uid,
      'local_id': localId,
      'name': item['name'] as String? ?? 'Item',
      'brand': _bind(item['brand']) ?? '',
      'category': _bind(item['category']) ?? 'General',
      'checked': (item['checked'] == true) ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> toggleShoppingItem(String localId, bool checked) async {
    final db = await _database;
    if (db == null) return;

    await db.update(
      'shopping_list',
      {'checked': checked ? 1 : 0},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteShoppingItem(String localId) async {
    final db = await _database;
    if (db == null) return;

    await db.delete(
      'shopping_list',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> clearCheckedShoppingItems() async {
    final db = await _database;
    if (db == null) return;

    final uids = _readableUids;
    await db.delete(
      'shopping_list',
      where:
          'checked = 1 AND user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: uids,
    );
  }

  // ──────────────────────────── Scan History ────────────────────────────

  /// Insert a scanned product into local history, replacing any earlier scan of
  /// the same barcode so history reads as "most recent scan per product".
  ///
  /// Returns the row id, or -1 on failure.
  Future<int> insertScan(Map<String, dynamic> product) async {
    final db = await _database;
    if (db == null) return -1;

    final barcode = (product['barcode'] as String? ?? '').trim();

    try {
      if (barcode.isNotEmpty) {
        await db.delete(
          'scan_history',
          where: 'barcode = ? AND user_id = ?',
          whereArgs: [barcode, _uid],
        );
      }

      return await db.insert('scan_history', {
        'user_id': _uid,
        'barcode': barcode,
        'name': _bind(product['name']),
        'brand': _bind(product['brand']),
        'category': _bind(product['category']),
        'image_url': _bind(product['image']),
        'nutrition_json': _encodeSafe(product['nutrition'] ?? const {}),
        'ingredients_json': _encodeSafe(product['ingredients'] ?? const []),
        'allergens_json': _encodeSafe(product['allergens'] ?? const []),
        'serving_size': _bind(product['servingSize']),
        'nutriscore': _bind(product['nutriscore']),
        'nova_group': (product['novaGroup'] as num?)?.toInt(),
        'quantity': _bind(product['quantity']),
        // aiAnalysis is a nested Map — must be encoded, not bound directly.
        'ai_analysis': product['aiAnalysis'] == null
            ? null
            : _encodeSafe(product['aiAnalysis']),
        'scanned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error inserting scan for barcode=$barcode: $e');
      return -1;
    }
  }

  /// Get scan history, most recent first.
  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 50}) async {
    final db = await _database;
    if (db == null) return [];

    try {
      final uids = _readableUids;
      final rows = await db.query(
        'scan_history',
        where: 'user_id IN (${List.filled(uids.length, '?').join(',')})',
        whereArgs: uids,
        orderBy: 'scanned_at DESC',
        limit: limit,
      );

      return rows.map(_rowToProduct).toList();
    } catch (e) {
      debugPrint('Error loading scan history: $e');
      return [];
    }
  }

  /// Look up a single cached product by barcode (offline product details).
  Future<Map<String, dynamic>?> getScanByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return null;
    final db = await _database;
    if (db == null) return null;

    try {
      final uids = _readableUids;
      final rows = await db.query(
        'scan_history',
        where:
            'barcode = ? AND user_id IN (${List.filled(uids.length, '?').join(',')})',
        whereArgs: [barcode, ...uids],
        orderBy: 'scanned_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _rowToProduct(rows.first);
    } catch (e) {
      debugPrint('Error reading cached scan: $e');
      return null;
    }
  }

  /// Clear the current user's local scan history.
  Future<void> clearScans() async {
    final db = await _database;
    if (db == null) return;
    final uids = _readableUids;
    await db.delete(
      'scan_history',
      where: 'user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: uids,
    );
  }

  /// Delete a scan from local history by barcode.
  /// No-op if barcode is empty.
  Future<void> deleteScanByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    final db = await _database;
    if (db == null) return;

    final uids = _readableUids;
    final deleted = await db.delete(
      'scan_history',
      where:
          'barcode = ? AND user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: [barcode, ...uids],
    );
    debugPrint('Deleted $deleted scan_history row(s) for barcode=$barcode');
  }

  /// Wipe every row belonging to the current user plus any un-adopted guest
  /// rows. Used on sign-out so the next account starts clean.
  ///
  /// Pass [forUid] when the caller has already signed out of Firebase — by then
  /// [_uid] has fallen back to [kLocalUid] and the departing user's rows would
  /// otherwise be left behind on the device.
  Future<void> clearAllLocalData({String? forUid}) async {
    final db = await _database;
    if (db == null) return;

    final uids = <String>{
      ..._readableUids,
      if (forUid != null && forUid.isNotEmpty) forUid,
    }.toList();
    final placeholders = List.filled(uids.length, '?').join(',');
    for (final table in ['diet_log', 'scan_history', 'shopping_list']) {
      await db.delete(table,
          where: 'user_id IN ($placeholders)', whereArgs: uids);
    }
    debugPrint(
        'LocalDatabaseService: cleared local tables for ${uids.join(", ")}.');
  }

  /// Clear the current user's diet log entries.
  Future<void> clearDietLog() async {
    final db = await _database;
    if (db == null) return;
    final uids = _readableUids;
    await db.delete(
      'diet_log',
      where: 'user_id IN (${List.filled(uids.length, '?').join(',')})',
      whereArgs: uids,
    );
  }

  Map<String, dynamic> _rowToProduct(Map<String, dynamic> row) {
    Map<String, dynamic> nutrition = {};
    List<dynamic> ingredients = [];
    List<dynamic> allergens = [];
    Map<String, dynamic>? aiAnalysis;

    try {
      nutrition =
          jsonDecode(row['nutrition_json'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    try {
      ingredients = jsonDecode(row['ingredients_json'] as String? ?? '[]') as List;
    } catch (_) {}
    try {
      allergens = jsonDecode(row['allergens_json'] as String? ?? '[]') as List;
    } catch (_) {}

    // Stored as a JSON string; callers expect a Map (or null).
    final rawAi = row['ai_analysis'];
    if (rawAi is String && rawAi.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAi);
        if (decoded is Map<String, dynamic>) aiAnalysis = decoded;
      } catch (_) {}
    } else if (rawAi is Map<String, dynamic>) {
      aiAnalysis = rawAi;
    }

    return {
      'barcode': row['barcode'],
      'name': row['name'],
      'brand': row['brand'],
      'category': row['category'],
      'image': row['image_url'],
      'nutrition': nutrition,
      'ingredients': ingredients.map((e) => e.toString()).toList(),
      'allergens': allergens.map((e) => e.toString()).toList(),
      'servingSize': row['serving_size'],
      'nutriscore': row['nutriscore'],
      'novaGroup': row['nova_group'],
      'quantity': row['quantity'],
      'aiAnalysis': aiAnalysis,
      'scannedAt': row['scanned_at'],
    };
  }
}
