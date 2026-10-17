import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_store.dart';

CacheStore createCacheStore({
  String? path,
  String namespace = 'responses',
  DateTime Function()? now,
  int maxEntries = 120,
  bool durable = false,
}) {
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(namespace)) {
    throw ArgumentError.value(namespace, 'namespace');
  }
  return _DriftCacheStore(
    path: path,
    namespace: namespace,
    now: now,
    maxEntries: maxEntries,
    durable: durable,
  );
}

final class _DriftCacheStore implements CacheStore {
  _DriftCacheStore({
    String? path,
    required String namespace,
    DateTime Function()? now,
    int maxEntries = 120,
    bool durable = false,
  }) : assert(maxEntries > 0),
       _now = now ?? DateTime.now,
       _maxEntries = maxEntries,
       _durable = durable,
       _database = _CacheDatabase(
         LazyDatabase(() async {
           final resolved =
               path ??
               '${(await getApplicationSupportDirectory()).path}/demobank/$namespace.sqlite';
           final file = File(resolved);
           await file.parent.create(recursive: true);
           return NativeDatabase.createInBackground(file);
         }),
       );

  final DateTime Function() _now;
  final int _maxEntries;
  final bool _durable;
  final _CacheDatabase _database;
  bool _closed = false;
  int _accessSequence = 0;

  @override
  Future<CacheEntry?> read(String key) async {
    _checkOpen();
    final rows = await _database
        .customSelect(
          'SELECT payload FROM cache_entries WHERE cache_key = ?',
          variables: [Variable<String>(key)],
        )
        .get();
    if (rows.isEmpty) return null;
    await _database.customStatement(
      'UPDATE cache_entries SET accessed_at = ? WHERE cache_key = ?',
      [_accessedAt, key],
    );
    try {
      return decodeEntry(rows.single.read<String>('payload'), _now);
    } on Object {
      // A response cache treats an unreadable row as a miss. A durable journal
      // keeps it: silently dropping recovery data could permit a second
      // submission, so the owner must decide explicitly.
      if (_durable) throw CorruptCacheEntry(key);
      await delete(key);
      return null;
    }
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) async {
    _checkOpen();
    final encoded = encodeEntry(value, _now(), ttl, revision);
    await _database.transaction(() async {
      await _database.customStatement(
        'INSERT INTO cache_entries (cache_key, payload, accessed_at) '
        'VALUES (?, ?, ?) ON CONFLICT(cache_key) DO UPDATE SET '
        'payload = excluded.payload, accessed_at = excluded.accessed_at',
        [key, encoded, _accessedAt],
      );
      if (_durable) return;
      await _database.customStatement(
        'DELETE FROM cache_entries WHERE cache_key IN '
        '(SELECT cache_key FROM cache_entries ORDER BY accessed_at DESC, '
        'cache_key DESC LIMIT -1 OFFSET ?)',
        [_maxEntries],
      );
    });
  }

  int get _accessedAt =>
      _now().microsecondsSinceEpoch * 1000 + _accessSequence++;

  @override
  Future<void> delete(String key) async {
    _checkOpen();
    await _database.customStatement(
      'DELETE FROM cache_entries WHERE cache_key = ?',
      [key],
    );
  }

  @override
  Future<String?> quarantine(String key) async {
    _checkOpen();
    final target = quarantineKey(key, _now());
    final moved = await _database.customUpdate(
      'UPDATE cache_entries SET cache_key = ? WHERE cache_key = ?',
      variables: [Variable<String>(target), Variable<String>(key)],
    );
    return moved == 0 ? null : target;
  }

  @override
  Future<void> clear() async {
    _checkOpen();
    await _database.customStatement('DELETE FROM cache_entries');
  }

  @override
  Future<void> expireAll() async {
    _checkOpen();
    await _database.transaction(() async {
      final entries = await _database
          .customSelect('SELECT cache_key, payload FROM cache_entries')
          .get();
      for (final entry in entries) {
        await _database.customStatement(
          'UPDATE cache_entries SET payload = ? WHERE cache_key = ?',
          [
            expireEntry(entry.read<String>('payload'), _now()),
            entry.read<String>('cache_key'),
          ],
        );
      }
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _database.close();
  }

  void _checkOpen() {
    if (_closed) throw StateError('CacheStore is closed');
  }
}

/// A single private SQL table needs no generated domain model. The schema and
/// migration are explicit and still use Drift's transactions and isolate API.
final class _CacheDatabase extends GeneratedDatabase {
  _CacheDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement(
      'CREATE TABLE cache_entries ('
      'cache_key TEXT PRIMARY KEY NOT NULL, '
      'payload TEXT NOT NULL, accessed_at INTEGER NOT NULL)',
    ),
  );
}
