// lib/core/services/local_database_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Service for efficient local persistence using SQLite.
///
/// Replaces SharedPreferences for structured data (diet log, scan history).
/// Each record is an individual row — no more serialising entire JSON arrays.
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;

  /// Initialise the database. Call once from `main()`.
  Future<void> initialize() async {
    if (_db != null && _db!.isOpen) return;

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'nutricore.db');

      _db = await openDatabase(
        path,
        version: 2,
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
        local_id TEXT NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT,
        checked INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_diet_log_date ON diet_log(date)');
    await db.execute('CREATE INDEX idx_scan_history_barcode ON scan_history(barcode)');
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
  }

  Future<Database?> get _database async {
    if (_db == null || !_db!.isOpen) {
      await initialize();
    }
    return _db;
  }

  // ──────────────────────────── Diet Log ────────────────────────────

  /// Insert a diet entry. Returns the row id.
  Future<int> insertDietEntry(Map<String, dynamic> entry) async {
    final db = await _database;
    if (db == null) return -1;

    final localId = entry['id'] as String? ?? 'local_${DateTime.now().millisecondsSinceEpoch}';

    return db.insert('diet_log', {
      'local_id': localId,
      'firestore_id': entry['firestoreId'],
      'name': entry['name'] ?? 'Unknown',
      'meal_type': entry['mealType'],
      'calories': (entry['calories'] as num?)?.toInt() ?? 0,
      'protein': (entry['protein'] as num?)?.toDouble() ?? 0,
      'sugar': (entry['sugar'] as num?)?.toDouble() ?? 0,
      'fat': (entry['fat'] as num?)?.toDouble() ?? 0,
      'carbs': (entry['carbs'] as num?)?.toDouble() ?? 0,
      'brand': entry['brand'],
      'time': entry['time'],
      'date': entry['date'],
      'sync_status': entry['source'] ?? 'local',
      'extra_json': jsonEncode(entry),
      'created_at': DateTime.now().toIso8601String(),
    });
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
      final rows = await db.query(
        'diet_log',
        where: 'date = ?',
        whereArgs: [dateString],
        orderBy: 'time DESC',
      );

      return rows.map(_rowToDietEntry).toList();
    } catch (e) {
      debugPrint('Error getting diet log by date: $e');
      return [];
    }
  }

  /// Delete a diet entry by its local_id or firestore_id.
  Future<void> deleteDietEntry(String entryId) async {
    final db = await _database;
    if (db == null) return;

    final deleted = await db.delete(
      'diet_log',
      where: 'local_id = ? OR firestore_id = ?',
      whereArgs: [entryId, entryId],
    );
    debugPrint('Deleted $deleted diet entry row(s) for id=$entryId');
  }

  /// Get all unsynced diet entries (for cloud sync on reconnect).
  Future<List<Map<String, dynamic>>> getUnsyncedDietEntries() async {
    final db = await _database;
    if (db == null) return [];

    final rows = await db.query(
      'diet_log',
      where: "sync_status = 'local'",
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

    final rows = await db.query(
      'shopping_list',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => {
      'id': r['local_id'],
      'name': r['name'],
      'brand': r['brand'] ?? '',
      'category': r['category'] ?? 'General',
      'checked': r['checked'] == 1,
      'createdAt': r['created_at'],
    }).toList();
  }

  Future<void> addShoppingItem(Map<String, dynamic> item) async {
    final db = await _database;
    if (db == null) return;

    final localId = 'shop_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('shopping_list', {
      'local_id': localId,
      'name': item['name'] ?? 'Item',
      'brand': item['brand'] ?? '',
      'category': item['category'] ?? 'General',
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

    await db.delete(
      'shopping_list',
      where: 'checked = 1',
    );
  }

  // ──────────────────────────── Scan History ────────────────────────────

  /// Insert a scanned product into local history.
  Future<int> insertScan(Map<String, dynamic> product) async {
    final db = await _database;
    if (db == null) return -1;

    final nutrition = product['nutrition'] as Map<String, dynamic>? ?? {};
    final ingredients = product['ingredients'] as List? ?? [];
    final allergens = product['allergens'] as List? ?? [];

    return db.insert('scan_history', {
      'barcode': product['barcode'] ?? '',
      'name': product['name'],
      'brand': product['brand'],
      'category': product['category'],
      'image_url': product['image'],
      'nutrition_json': jsonEncode(nutrition),
      'ingredients_json': jsonEncode(ingredients),
      'allergens_json': jsonEncode(allergens),
      'serving_size': product['servingSize'],
      'nutriscore': product['nutriscore'],
      'nova_group': product['novaGroup'],
      'quantity': product['quantity'],
      'ai_analysis': product['aiAnalysis'],
      'scanned_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get scan history, most recent first.
  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 50}) async {
    final db = await _database;
    if (db == null) return [];

    try {
      final rows = await db.query(
        'scan_history',
        orderBy: 'scanned_at DESC',
        limit: limit,
      );

      return rows.map(_rowToProduct).toList();
    } catch (e) {
      debugPrint('Error loading scan history: $e');
      return [];
    }
  }

  /// Clear all local scan history (used on sign-out).
  Future<void> clearScans() async {
    final db = await _database;
    if (db == null) return;
    await db.delete('scan_history');
  }

  /// Delete a scan from local history by barcode.
  /// No-op if barcode is empty.
  Future<void> deleteScanByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    final db = await _database;
    if (db == null) return;

    final deleted = await db.delete(
      'scan_history',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    debugPrint('Deleted $deleted scan_history row(s) for barcode=$barcode');
  }

  /// Clear all local tables (used on user sign-out to prevent data leakage across accounts).
  Future<void> clearAllLocalData() async {
    final db = await _database;
    if (db == null) return;

    await db.delete('diet_log');
    await db.delete('scan_history');
    await db.delete('shopping_list');
    debugPrint('LocalDatabaseService: Cleared all local tables for account switch.');
  }

  /// Clear all local diet log entries (used on sign-out).
  Future<void> clearDietLog() async {
    final db = await _database;
    if (db == null) return;
    await db.delete('diet_log');
  }

  Map<String, dynamic> _rowToProduct(Map<String, dynamic> row) {
    Map<String, dynamic> nutrition = {};
    List<dynamic> ingredients = [];
    List<dynamic> allergens = [];

    try {
      nutrition = jsonDecode(row['nutrition_json'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    try {
      ingredients = jsonDecode(row['ingredients_json'] as String? ?? '[]') as List;
    } catch (_) {}
    try {
      allergens = jsonDecode(row['allergens_json'] as String? ?? '[]') as List;
    } catch (_) {}

    return {
      'barcode': row['barcode'],
      'name': row['name'],
      'brand': row['brand'],
      'category': row['category'],
      'image': row['image_url'],
      'nutrition': nutrition,
      'ingredients': ingredients.cast<String>(),
      'allergens': allergens.cast<String>(),
      'servingSize': row['serving_size'],
      'nutriscore': row['nutriscore'],
      'novaGroup': row['nova_group'],
      'quantity': row['quantity'],
      'aiAnalysis': row['ai_analysis'],
      'scannedAt': row['scanned_at'],
    };
  }
}
