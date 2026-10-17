import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final persistent in [false, true]) {
    group(persistent ? 'isolated Drift cache' : 'memory cache', () {
      late Directory directory;
      late CacheStore store;
      late DateTime now;
      setUp(() async {
        directory = await Directory.systemTemp.createTemp('demobank-cache-');
        now = DateTime.utc(2026, 10, 16, 12);
        store = persistent
            ? CacheStore(
                path: '${directory.path}/cache.sqlite',
                now: () => now,
                maxEntries: 2,
              )
            : MemoryCacheStore(now: () => now, maxEntries: 2);
      });
      tearDown(() async {
        await store.close();
        await directory.delete(recursive: true);
      });

      test(
        'freshness, preserved stale data, and explicit expiration',
        () async {
          final value = {
            'items': [1, 2],
            'filter': 'dining',
          };
          await store.write(
            'page',
            value,
            ttl: const Duration(minutes: 1),
            revision: '4',
          );
          value['filter'] = 'changed';
          final entry = (await store.read('page'))!;
          expect(entry.value['filter'], 'dining');
          expect(entry.revision, '4');
          expect(entry.isFresh, isTrue);
          now = now.add(const Duration(minutes: 2));
          expect(entry.isFresh, isFalse);
          expect((await store.read('page'))!.value['items'], [1, 2]);
          await store.write('fresh', {'ok': true});
          await store.expireAll();
          expect((await store.read('fresh'))!.isFresh, isFalse);
          expect((await store.read('page'))!.revision, '4');
        },
      );

      test('bounded LRU eviction, delete and clear', () async {
        await store.write('a', {'id': 'a'});
        await store.write('b', {'id': 'b'});
        await store.read('a');
        await store.write('c', {'id': 'c'});
        expect(await store.read('b'), isNull);
        expect(await store.read('a'), isNotNull);
        expect(await store.read('c'), isNotNull);
        await store.delete('a');
        expect(await store.read('a'), isNull);
        await store.clear();
        expect(await store.read('c'), isNull);
      });

      test('closed stores reject later work', () async {
        await store.close();
        await expectLater(store.read('a'), throwsStateError);
      });
    });
  }

  test(
    'native cache reopens with filter, revision and freshness intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'demobank-cache-reopen-',
      );
      final path = '${directory.path}/nested/cache.sqlite';
      final before = CacheStore(path: path);
      expect(
        await File(path).exists(),
        isFalse,
        reason: 'Constructor must not perform IO',
      );
      await before.write('filter/main/2026-10', {
        'totalMinor': 12345,
      }, revision: '9');
      await before.close();
      final reopened = CacheStore(path: path);
      final entry = (await reopened.read('filter/main/2026-10'))!;
      expect(entry.value['totalMinor'], 12345);
      expect(entry.revision, '9');
      expect(entry.isFresh, isTrue);
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'readDecoded drops malformed values but surfaces programming errors',
    () async {
      final store = MemoryCacheStore();
      addTearDown(store.close);
      await store.write('old', {'schema': 0});
      expect(
        await store.readDecoded<String>(
          'old',
          (_) => throw const FormatException('older schema'),
        ),
        isNull,
      );
      expect(await store.read('old'), isNull);
      await store.write('kept', {'ok': true});
      await expectLater(
        store.readDecoded('kept', (value) => value['name'] as String),
        throwsA(isA<TypeError>()),
      );
      expect(await store.read('kept'), isNotNull);
    },
  );

  test('quarantine keeps the raw entry under a new key', () async {
    final store = MemoryCacheStore(durable: true);
    addTearDown(store.close);
    await store.write('pending_payment', {'value': 'raw'});
    final archived = await store.quarantine('pending_payment');
    expect(archived, startsWith('pending_payment.unreadable.'));
    expect(await store.read('pending_payment'), isNull);
    expect((await store.read(archived!))!.value['value'], 'raw');
    expect(await store.quarantine('pending_payment'), isNull);
  });

  test('durable memory store never evicts', () async {
    final store = MemoryCacheStore(maxEntries: 1, durable: true);
    addTearDown(store.close);
    await store.write('pending_payment', {'value': 'a'});
    await store.write('simulator_state', {'value': 'b'});
    expect(await store.read('pending_payment'), isNotNull);
    expect(await store.read('simulator_state'), isNotNull);
  });

  test(
    'durable native store keeps and reports a corrupt row; a cache drops it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'demobank-durable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      void corrupt(String path, String key) {
        final database = sqlite.sqlite3.open(path);
        try {
          database.execute(
            'UPDATE cache_entries SET payload = ? WHERE cache_key = ?',
            ['{broken', key],
          );
        } finally {
          database.dispose();
        }
      }

      final journalPath = '${directory.path}/journal.sqlite';
      final writer = CacheStore(path: journalPath, durable: true);
      await writer.write('pending_payment', {'value': 'key-1'});
      await writer.write('other', {'value': 'kept'});
      await writer.close();
      corrupt(journalPath, 'pending_payment');

      final journal = CacheStore(
        path: journalPath,
        durable: true,
        maxEntries: 1,
      );
      await expectLater(
        journal.read('pending_payment'),
        throwsA(isA<CorruptCacheEntry>()),
      );
      await journal.write('third', {'value': 'new'});
      expect(await journal.read('other'), isNotNull);
      expect(await journal.read('third'), isNotNull);
      await expectLater(
        journal.read('pending_payment'),
        throwsA(isA<FormatException>()),
        reason: 'A corrupt durable row stays until explicitly deleted',
      );
      final archived = await journal.quarantine('pending_payment');
      expect(archived, startsWith('pending_payment.unreadable.'));
      expect(await journal.read('pending_payment'), isNull);
      await expectLater(
        journal.read(archived!),
        throwsA(isA<CorruptCacheEntry>()),
        reason: 'The raw row is preserved for diagnosis, not repaired',
      );
      expect(await journal.quarantine('pending_payment'), isNull);
      await journal.close();

      final cachePath = '${directory.path}/cache.sqlite';
      final cacheWriter = CacheStore(path: cachePath);
      await cacheWriter.write('accounts', {'accounts': <Object>[]});
      await cacheWriter.close();
      corrupt(cachePath, 'accounts');
      final cache = CacheStore(path: cachePath);
      expect(await cache.read('accounts'), isNull);
      await cache.close();
    },
  );
}
