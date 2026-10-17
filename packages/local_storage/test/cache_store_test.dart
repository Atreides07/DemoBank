import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

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
}
