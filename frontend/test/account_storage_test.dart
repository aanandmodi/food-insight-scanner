import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:food_insight_scanner/services/user_record_store.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late UserRecordStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await UserRecordStore.createSchema(db);
    store = UserRecordStore.withDatabase(db);
  });
  tearDown(() => db.close());
  test('same record ID is isolated across accounts and survives reopening',
      () async {
    await store.put('alice', 'diet_entries', 'meal', {'name': 'Dal'});
    await store.put('bob', 'diet_entries', 'meal', {'name': 'Idli'});
    store = UserRecordStore.withDatabase(db);
    expect((await store.read('alice', 'diet_entries')).single['name'], 'Dal');
    expect((await store.read('bob', 'diet_entries')).single['name'], 'Idli');
    await store.clearOwner('alice');
    expect(await store.read('alice', 'diet_entries'), isEmpty);
    expect((await store.read('bob', 'diet_entries')).length, 1);
  });
  test('idempotent retry does not duplicate calories', () async {
    for (var i = 0; i < 3; i++) {
      await store.put('alice', 'diet_entries', 'same-meal', {'calories': 300});
    }
    expect((await store.read('alice', 'diet_entries')).length, 1);
  });
  test('acknowledgement of older upload cannot discard a newer edit', () async {
    await store.put('alice', 'shopping_items', 'item', {'checked': false},
        updatedAt: '2026-09-18T01:00:00Z');
    final pending = (await store.pending('alice')).single;
    await store.put('alice', 'shopping_items', 'item', {'checked': true},
        updatedAt: '2026-09-18T01:00:01Z');
    await store.acknowledge(pending);
    expect((await store.pending('alice')).length, 1);
  });
  test('cloud refresh does not resurrect offline deletion', () async {
    await store.put('alice', 'scans', '123', {}, deleted: true);
    await store.mergeRemote('alice', 'scans', [
      {
        'user_id': 'alice',
        'id': '123',
        'data': {'name': 'Old scan'},
        'updated_at': '2026-09-18T01:00:00Z',
        'deleted': false
      }
    ]);
    expect(await store.read('alice', 'scans'), isEmpty);
    expect((await store.pending('alice')).single['deleted'], 1);
  });
  test('reject cloud row from another UID and unowned local sentinel',
      () async {
    await expectLater(
        store.mergeRemote('alice', 'scans', [
          {'user_id': 'bob', 'id': '123', 'data': {}}
        ]),
        throwsStateError);
    await expectLater(
        store.put('__local__', 'scans', '123', {}), throwsArgumentError);
  });
  test(
      'restores remote scans and diet logs without timestamp conversion errors',
      () async {
    for (final table in ['scans', 'diet_entries']) {
      await store.mergeRemote('alice', table, [
        {
          'user_id': 'alice',
          'id': 'saved',
          'data': {'scannedAt': '2026-09-18T01:00:00Z', 'date': '2026-09-18'},
          'updated_at': '2026-09-18T01:00:00Z',
          'deleted': false
        }
      ]);
      final restored = (await store.read('alice', table)).single;
      expect(DateTime.parse(restored['scannedAt'] as String).year, 2026);
      expect(await store.read('bob', table), isEmpty);
    }
  });
}
