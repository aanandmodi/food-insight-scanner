import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Persistent outbox and cache. All methods require an explicit owner captured
/// before any async work; there is no shared/guest namespace.
class UserRecordStore {
  static final instance = UserRecordStore();
  Database? _db;
  Future<Database>? _opening;
  UserRecordStore();
  UserRecordStore.withDatabase(Database database) : _db = database;
  Future<Database> get database async => _db ??= await (_opening ??= _open());

  Future<Database> _open() async => openDatabase(
        p.join(await getDatabasesPath(), 'food_insight_accounts.db'),
        version: 1,
        onCreate: (db, _) => createSchema(db),
      );
  static Future<void> createSchema(Database db) => db.execute('''
    CREATE TABLE records (
      user_id TEXT NOT NULL, collection TEXT NOT NULL, id TEXT NOT NULL,
      data TEXT NOT NULL, updated_at TEXT NOT NULL,
      dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(user_id, collection, id)
    )
  ''');
  static void _owner(String uid) {
    if (uid.isEmpty || uid == '__local__') {
      throw ArgumentError('An authenticated UID is required');
    }
  }

  Future<void> put(
      String uid, String collection, String id, Map<String, dynamic> data,
      {bool dirty = true, bool deleted = false, String? updatedAt}) async {
    _owner(uid);
    final db = await database;
    await db.insert(
        'records',
        {
          'user_id': uid,
          'collection': collection,
          'id': id,
          'data': jsonEncode({...data, 'id': id}),
          'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
          'dirty': dirty ? 1 : 0,
          'deleted': deleted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> rows(String uid, String collection,
      {bool includeDeleted = false}) async {
    _owner(uid);
    return (await database).query('records',
        where:
            'user_id = ? AND collection = ?${includeDeleted ? '' : ' AND deleted = 0'}',
        whereArgs: [uid, collection],
        orderBy: 'updated_at DESC');
  }

  Future<List<Map<String, dynamic>>> read(
          String uid, String collection) async =>
      (await rows(uid, collection))
          .map((r) =>
              Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map))
          .toList();
  Future<List<Map<String, dynamic>>> pending(String uid) async {
    _owner(uid);
    return (await database)
        .query('records', where: 'user_id = ? AND dirty = 1', whereArgs: [uid]);
  }

  Future<void> acknowledge(Map<String, dynamic> row) async {
    // A newer edit made during the request must remain pending.
    await (await database).update('records', {'dirty': 0},
        where: 'user_id = ? AND collection = ? AND id = ? AND updated_at = ?',
        whereArgs: [
          row['user_id'],
          row['collection'],
          row['id'],
          row['updated_at']
        ]);
  }

  Future<void> mergeRemote(
      String uid, String collection, List<Map<String, dynamic>> remote) async {
    _owner(uid);
    final db = await database;
    await db.transaction((txn) async {
      for (final r in remote) {
        if (r['user_id'] != uid) {
          throw StateError('Cloud row has a different owner');
        }
        final id = r['id'] as String;
        final existing = await txn.query('records',
            where: 'user_id = ? AND collection = ? AND id = ?',
            whereArgs: [uid, collection, id]);
        if (existing.isNotEmpty && existing.first['dirty'] == 1) continue;
        await txn.insert(
            'records',
            {
              'user_id': uid,
              'collection': collection,
              'id': id,
              'data': jsonEncode(
                  {...Map<String, dynamic>.from(r['data'] as Map), 'id': id}),
              'updated_at': r['updated_at'],
              'deleted': r['deleted'] == true ? 1 : 0,
              'dirty': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> clearOwner(String uid) async {
    _owner(uid);
    await (await database)
        .delete('records', where: 'user_id = ?', whereArgs: [uid]);
  }
}
