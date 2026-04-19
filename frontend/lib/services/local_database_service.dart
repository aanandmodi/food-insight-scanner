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
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'nutricore.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );

    debugPrint('LocalDatabaseService initialised at $path');
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

    await db.execute('CREATE INDEX idx_diet_log_date ON diet_log(date)');
    await db.execute('CREATE INDEX idx_scan_history_barcode ON scan_history(barcode)');
  }

  Database get _database {
    if (_db == null) throw StateError('LocalDatabaseService not initialised. Call initialize() first.');
    return _db!;
  }

  // ──────────────────────────── Diet Log ────────────────────────────

  /// Insert a diet entry. Returns the row id.
  Future<int> insertDietEntry(Map<String, dynamic> entry) async {
    final localId = entry['id'] as String? ?? 'local_${DateTime.now().millisecondsSinceEpoch}';

    return _database.insert('diet_log', {
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
    await _database.update(
      'diet_log',
      {'firestore_id': firestoreId, 'sync_status': 'synced'},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Get diet entries for a specific date (YYYY-MM-DD).
  Future<List<Map<String, dynamic>>> getDietLogByDate(String dateString) async {
    final rows = await _database.query(
      'diet_log',
      where: 'date = ?',
      whereArgs: [dateString],
      orderBy: 'time DESC',
    );

    return rows.map(_rowToDietEntry).toList();
  }

  /// Delete a diet entry by its local_id or firestore_id.
  Future<void> deleteDietEntry(String entryId) async {
    final deleted = await _database.delete(
      'diet_log',
      where: 'local_id = ? OR firestore_id = ?',
      whereArgs: [entryId, entryId],
    );
    debugPrint('Deleted $deleted diet entry row(s) for id=$entryId');
  }

  /// Get all unsynced diet entries (for cloud sync on reconnect).
  Future<List<Map<String, dynamic>>> getUnsyncedDietEntries() async {
    final rows = await _database.query(
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

  // ──────────────────────────── Scan History ────────────────────────────

  /// Insert a scanned product into local history.
  Future<int> insertScan(Map<String, dynamic> product) async {
    final nutrition = product['nutrition'] as Map<String, dynamic>? ?? {};
    final ingredients = product['ingredients'] as List? ?? [];
    final allergens = product['allergens'] as List? ?? [];

    return _database.insert('scan_history', {
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
    final rows = await _database.query(
      'scan_history',
      orderBy: 'scanned_at DESC',
      limit: limit,
    );

    return rows.map(_rowToProduct).toList();
  }

  /// Clear all local scan history (used on sign-out).
  Future<void> clearScans() async {
    await _database.delete('scan_history');
  }

  /// Clear all local diet log entries (used on sign-out).
  Future<void> clearDietLog() async {
    await _database.delete('diet_log');
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
