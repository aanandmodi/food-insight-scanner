import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/data_refresh_bus.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';
import 'user_preferences.dart';
import 'user_record_store.dart';
import 'user_session.dart';

/// Firebase UID is the sole owner key. Supabase RLS also enforces ownership.
/// Writes go through a durable SQLite outbox and use the same ID remotely.
class UserDataService {
  static final _instance = UserDataService._();
  factory UserDataService() => _instance;
  UserDataService._();
  final _store = UserRecordStore.instance;
  final _changes = StreamController<String>.broadcast();
  final Map<String, Future<void>> _syncs = {};
  final Map<String, Future<void>> _migrations = {};
  final Map<String, DateTime> _migrationRetry = {};
  String? lastSyncError;
  static const tables = [
    'profiles',
    'scans',
    'diet_entries',
    'shopping_items',
    'meal_plans',
    'chat_messages',
    'activity_logs'
  ];
  static String newId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}_${List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  void _notify(String table) {
    _changes.add(table);
    if (table == 'scans') DataRefreshBus.scanHistoryChanged();
    if (table == 'diet_entries') DataRefreshBus.dietLogChanged();
    if (table == 'profiles') DataRefreshBus.profileChanged();
  }

  Future<bool> _save(
      SessionToken session, String table, String id, Map<String, dynamic> data,
      {bool deleted = false}) async {
    session.check();
    await _store.put(session.uid, table, id, data, deleted: deleted);
    session.check();
    _notify(table);
    await _sync(session);
    session.check();
    return !(await _store.pending(session.uid))
        .any((r) => r['collection'] == table && r['id'] == id);
  }

  Future<void> _sync(SessionToken session) async {
    final existing = _syncs[session.uid];
    if (existing != null) {
      await existing;
      session.check();
    }
    final task = _upload(session);
    _syncs[session.uid] = task;
    try {
      await task;
    } finally {
      if (identical(_syncs[session.uid], task)) _syncs.remove(session.uid);
    }
  }

  Future<void> _upload(SessionToken session) async {
    try {
      for (final row in await _store.pending(session.uid)) {
        session.check();
        await SupabaseService.client.from(row['collection'] as String).upsert({
          'user_id': session.uid,
          'id': row['id'],
          'data': jsonDecode(row['data'] as String),
          'updated_at': row['updated_at'],
          'deleted': row['deleted'] == 1,
        }, onConflict: 'user_id,id').timeout(const Duration(seconds: 10));
        session.check();
        await _store.acknowledge(row);
      }
      lastSyncError = null;
    } on SessionChangedException {
      rethrow;
    } catch (error) {
      lastSyncError =
          'Cloud sync is pending. Your changes are saved on this device.';
      debugPrint('Supabase sync pending: $error');
    }
  }

  Future<List<Map<String, dynamic>>> _read(
      SessionToken session, String table) async {
    session.check();
    await _sync(session);
    try {
      // Paginate: Supabase defaults to 1,000 rows per response.
      final remote = <Map<String, dynamic>>[];
      for (var start = 0;; start += 500) {
        session.check();
        final page = await SupabaseService.client
            .from(table)
            .select()
            .eq('user_id', session.uid)
            .order('id')
            .range(start, start + 499)
            .timeout(const Duration(seconds: 10));
        session.check();
        remote.addAll(page);
        if (page.length < 500) break;
      }
      await _store.mergeRemote(session.uid, table, remote);
      lastSyncError = null;
    } on SessionChangedException {
      rethrow;
    } catch (error) {
      lastSyncError =
          'Cloud data could not load. Showing data saved on this device.';
      debugPrint('Supabase read $table: $error');
      final cached = await _store.read(session.uid, table);
      session.check();
      if (cached.isEmpty && table == 'profiles') rethrow;
    }
    session.check();
    final rows = await _store.read(session.uid, table);
    session.check();
    return rows;
  }

  Stream<List<Map<String, dynamic>>> _watch(
      String table, Future<List<Map<String, dynamic>>> Function() read) {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<String>? changes;
    Timer? timer;
    var loading = false;
    var rerun = false;
    Future<void> refresh() async {
      if (loading) {
        rerun = true;
        return;
      }
      loading = true;
      do {
        rerun = false;
        try {
          if (UserSession.instance.uid == null) {
            controller.add([]);
            break;
          }
          final session = UserSession.instance.capture();
          final cached = await _store.read(session.uid, table);
          if (!controller.isClosed && session.isActive) controller.add(cached);
          final data = await read();
          if (!controller.isClosed && session.isActive) controller.add(data);
        } on SessionChangedException {
          /* The next refresh belongs to the new user. */
        } catch (error, stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        }
      } while (rerun && !controller.isClosed);
      loading = false;
    }

    void sessionChanged() {
      controller.add([]);
      refresh();
    }

    controller = StreamController<List<Map<String, dynamic>>>(onListen: () {
      changes = _changes.stream
          .where((event) => event == table)
          .listen((_) => refresh());
      UserSession.instance.addListener(sessionChanged);
      timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
      refresh();
    }, onCancel: () async {
      timer?.cancel();
      UserSession.instance.removeListener(sessionChanged);
      await changes?.cancel();
    });
    return controller.stream;
  }

  Future<bool> saveUserProfile(Map<String, dynamic> profile) {
    final session = UserSession.instance.capture();
    if (profile['uid'] != null && profile['uid'] != session.uid) {
      throw SessionChangedException();
    }
    return _save(
        session, 'profiles', 'profile', {...profile, 'uid': session.uid});
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (UserSession.instance.uid == null) return null;
    final session = UserSession.instance.capture();
    await _migrateLegacy(session);
    final rows = await _read(session, 'profiles');
    session.check();
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> isProfileCompleted() async =>
      (await getUserProfile())?['profileCompleted'] == true;
  Future<void> clearLocalOwner(String uid) => _store.clearOwner(uid);

  Future<void> deleteUserProfile() async {
    final session = UserSession.instance.capture();
    // Explicit account deletion requires online confirmation from every table.
    for (final table in tables.reversed) {
      session.check();
      await SupabaseService.client
          .from(table)
          .delete()
          .eq('user_id', session.uid)
          .timeout(const Duration(seconds: 15));
    }
    await _store.clearOwner(session.uid);
  }

  Future<bool> saveScan(Map<String, dynamic> data) {
    final session = UserSession.instance.capture();
    final id = (data['barcode'] ?? data['id'] ?? newId()).toString();
    return _save(session, 'scans', id,
        {...data, 'scannedAt': DateTime.now().toUtc().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> cachedScans() async {
    final session = UserSession.instance.capture();
    final rows = await _store.read(session.uid, 'scans');
    session.check();
    rows.sort((a, b) => '${b['scannedAt']}'.compareTo('${a['scannedAt']}'));
    return rows;
  }

  Future<List<Map<String, dynamic>>> cachedDiet(String date) async {
    final session = UserSession.instance.capture();
    final rows = await _store.read(session.uid, 'diet_entries');
    session.check();
    return rows.where((r) => r['date'] == date).toList();
  }

  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 50}) async {
    final rows = await _read(UserSession.instance.capture(), 'scans');
    rows.sort((a, b) => '${b['scannedAt']}'.compareTo('${a['scannedAt']}'));
    return rows.take(limit).toList();
  }

  Stream<List<Map<String, dynamic>>> scanHistoryStream({int limit = 50}) =>
      _watch('scans', () => getScanHistory(limit: limit));
  Future<void> deleteScan(String id) async {
    await _save(UserSession.instance.capture(), 'scans', id, {}, deleted: true);
  }

  Future<bool> saveDietEntry(Map<String, dynamic> entry) {
    final now = DateTime.now();
    return _save(
        UserSession.instance.capture(),
        'diet_entries',
        (entry['id'] ?? newId()).toString(),
        {
          ...entry,
          'date': entry['date'] ?? now.toIso8601String().split('T')[0],
          'time': entry['time'] ??
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'createdAt': entry['createdAt'] is String
              ? entry['createdAt']
              : now.toUtc().toIso8601String(),
        }..remove('timestamp'));
  }

  Future<List<Map<String, dynamic>>> getDietLog(String date) async {
    final rows = (await _read(UserSession.instance.capture(), 'diet_entries'))
        .where((e) => e['date'] == date)
        .toList();
    rows.sort((a, b) => '${b['time']}'.compareTo('${a['time']}'));
    return rows;
  }

  Future<List<Map<String, dynamic>>> getRecentDietLogs({int days = 7}) async {
    final now = DateTime.now();
    final end = now.toIso8601String().split('T')[0];
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days.clamp(1, 7) - 1))
        .toIso8601String()
        .split('T')[0];
    final rows = await _read(UserSession.instance.capture(), 'diet_entries');
    return rows.where((row) {
      final date = row['date'];
      return date is String &&
          date.compareTo(start) >= 0 &&
          date.compareTo(end) <= 0;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> dietLogStream(String date) =>
      _watch('diet_entries', () => getDietLog(date))
          .map((rows) => rows.where((e) => e['date'] == date).toList());
  Future<void> deleteDietEntry(String id) async {
    await _save(UserSession.instance.capture(), 'diet_entries', id, {},
        deleted: true);
  }

  Future<void> addShoppingItem(Map<String, dynamic> item) async {
    await _save(UserSession.instance.capture(), 'shopping_items',
        (item['id'] ?? newId()).toString(), {
      ...item,
      'checked': false,
      'addedAt': DateTime.now().toUtc().toIso8601String()
    });
  }

  Future<List<Map<String, dynamic>>> getShoppingList() =>
      _read(UserSession.instance.capture(), 'shopping_items');
  Stream<List<Map<String, dynamic>>> shoppingListStream() =>
      _watch('shopping_items', getShoppingList);
  Future<void> toggleShoppingItem(String id, bool checked) async {
    final session = UserSession.instance.capture();
    final rows = await _store.read(session.uid, 'shopping_items');
    final item = rows.where((e) => e['id'] == id).firstOrNull;
    if (item != null) {
      await _save(session, 'shopping_items', id, {...item, 'checked': checked});
    }
  }

  Future<void> deleteShoppingItem(String id) async {
    await _save(UserSession.instance.capture(), 'shopping_items', id, {},
        deleted: true);
  }

  Future<void> clearCheckedShoppingItems() async {
    final session = UserSession.instance.capture();
    for (final item in await _store.read(session.uid, 'shopping_items')) {
      if (item['checked'] == true) {
        await _save(session, 'shopping_items', item['id'] as String, {},
            deleted: true);
      }
    }
  }

  Future<void> syncLocalEntriesToCloud() async {
    if (UserSession.instance.uid != null) {
      await _sync(UserSession.instance.capture());
    }
  }

  Future<Map<String, dynamic>?> getActivity(String date) async =>
      (await _read(UserSession.instance.capture(), 'activity_logs'))
          .where((r) => r['id'] == date)
          .firstOrNull;
  Future<void> saveActivity(
      Map<String, dynamic> data, SessionToken session) async {
    await _save(session, 'activity_logs',
        DateTime.now().toIso8601String().split('T')[0], data);
  }

  Future<Map<String, dynamic>?> getMealPlan() async {
    final rows = await _read(UserSession.instance.capture(), 'meal_plans');
    return rows.firstOrNull;
  }

  Future<void> saveMealPlan(
      Map<String, dynamic> plan, SessionToken session) async {
    await _save(session, 'meal_plans', 'latest', plan);
  }

  Future<List<Map<String, dynamic>>> getChatMessages() async {
    final rows = await _read(UserSession.instance.capture(), 'chat_messages');
    rows.sort((a, b) => '${a['timestamp']}'.compareTo('${b['timestamp']}'));
    return rows;
  }

  Future<void> saveChatMessage(
      Map<String, dynamic> message, SessionToken session) async {
    await _save(session, 'chat_messages', (message['id'] ?? newId()).toString(),
        message);
  }

  Future<Map<String, int>> getDailyCalorieTotals({int days = 7}) async {
    final rows = await _read(UserSession.instance.capture(), 'diet_entries');
    final result = <String, int>{};
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .split('T')[0];
    for (final row in rows) {
      final date = row['date']?.toString() ?? '';
      if (date.compareTo(cutoff) > 0) {
        result[date] =
            (result[date] ?? 0) + ((row['calories'] as num?)?.round() ?? 0);
      }
    }
    return result;
  }

  Future<void> _migrateLegacy(SessionToken session) async {
    if (_migrationRetry[session.uid]?.isAfter(DateTime.now()) == true) return;
    final existing = _migrations[session.uid];
    if (existing != null) return existing;
    final task = _importLegacy(session);
    _migrations[session.uid] = task;
    try {
      await task;
    } finally {
      _migrations.remove(session.uid);
    }
  }

  static dynamic _jsonSafe(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
    }
    if (value is List) return value.map(_jsonSafe).toList();
    return value;
  }

  Future<void> _importLegacy(SessionToken session) async {
    final prefs = await UserPreferences.getInstance();
    session.check();
    if (prefs.getBool('legacy_migrated_v1') == true) return;
    Future<void> importRows(
        String table, List<Map<String, dynamic>> rows) async {
      final known =
          (await _store.rows(session.uid, table, includeDeleted: true))
              .map((r) => r['id'])
              .toSet();
      for (final row in rows) {
        session.check();
        final id = (table == 'profiles'
                ? 'profile'
                : table == 'scans'
                    ? row['barcode'] ?? row['id']
                    : row['firestoreId'] ?? row['id'])
            ?.toString();
        if (id == null || id.isEmpty || known.contains(id)) continue;
        await _store.put(session.uid, table, id,
            Map<String, dynamic>.from(_jsonSafe(row) as Map));
        known.add(id);
      }
    }

    // Import the exact UID's old SQLite rows; never the __local__ sentinel.
    await importRows(
        'scans', await LocalDatabaseService().getScanHistory(limit: 100000));
    await importRows(
        'shopping_items', await LocalDatabaseService().getShoppingList());
    await importRows(
        'diet_entries', await LocalDatabaseService().getAllDietEntries());
    var complete = true;
    try {
      final db = FirebaseFirestore.instance;
      final profile = await db
          .collection('users')
          .doc(session.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      if (profile.exists) {
        await importRows('profiles', [
          {...profile.data()!, 'uid': session.uid}
        ]);
      }
      for (final mapping in [
        ['scan_history', 'scans', 'scans'],
        ['diet_log', 'entries', 'diet_entries'],
        ['shopping_list', 'items', 'shopping_items']
      ]) {
        final snapshot = await db
            .collection(mapping[0])
            .doc(session.uid)
            .collection(mapping[1])
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
        await importRows(mapping[2],
            snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList());
      }
    } on SessionChangedException {
      rethrow;
    } catch (error) {
      complete = false;
      _migrationRetry[session.uid] =
          DateTime.now().add(const Duration(minutes: 5));
      debugPrint('Legacy cloud migration pending: $error');
    }
    session.check();
    await _sync(session);
    if (complete && (await _store.pending(session.uid)).isEmpty) {
      await prefs.setBool('legacy_migrated_v1', true);
    }
  }
}
