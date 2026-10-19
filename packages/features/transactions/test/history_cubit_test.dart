import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:transactions/transactions.dart';

void main() {
  _registerAnchorTests();
  test(
    'loading flags reuse projection and unchanged page slots retain identity',
    () async {
      final cubit = HistoryCubit(_Reader());
      addTearDown(cubit.close);
      await cubit.load();
      final before = cubit.state;
      final slots = before.slots;
      expect(before.slots, same(slots));
      final loading = cubit.stream.firstWhere((s) => s.loadingPages.isNotEmpty);
      final next = cubit.loadNext();
      final status = await loading;
      expect(status.slots, same(slots));
      expect(status.pages, same(before.pages));
      expect(status.ids, same(before.ids));
      expect(status.days, same(before.days));
      await next;
      final extended = cubit.state.slots;
      expect(extended.length, 60);
      expect(extended, same(cubit.state.slots));
      for (var i = 0; i < 30; i++) {
        expect(extended[i], same(slots[i]));
      }
      expect(() => extended.clear(), throwsUnsupportedError);
    },
  );

  test(
    'retry requests the failed filter while keeping old rows coherent',
    () async {
      var fail = false;
      Completer<void>? retryGate;
      final requests = <LedgerFilter>[];
      final cubit = HistoryCubit(
        _Reader(
          request: (filter, _, _) async {
            requests.add(filter);
            if (fail) throw StateError('offline');
            if (retryGate != null) await retryGate.future;
            return _page();
          },
        ),
      );
      addTearDown(cubit.close);
      final old = LedgerFilter(category: 'groceries');
      final target = LedgerFilter(category: 'dining');
      await cubit.load(filter: old);
      fail = true;
      await cubit.load(filter: target);
      expect(cubit.state.filter, old);
      expect(cubit.state.failed, isTrue);
      fail = false;
      retryGate = Completer();
      final retry = cubit.retry();
      await cubit.retry();
      retryGate.complete();
      await retry;
      expect(requests, [old, target, target]);
      expect(cubit.state.filter, target);
      expect(cubit.state.failed, isFalse);
    },
  );
  test('latest filter wins when requests complete in reverse order', () async {
    final first = Completer<LedgerPage>();
    final second = Completer<LedgerPage>();
    final reader = _Reader(
      request: (filter, _, _) =>
          filter.category == 'groceries' ? first.future : second.future,
    );
    final cubit = HistoryCubit(reader);
    addTearDown(cubit.close);
    final older = cubit.load(filter: LedgerFilter(category: 'groceries'));
    await _turn();
    expect(reader.requests, hasLength(1));
    final newer = cubit.load(filter: LedgerFilter(category: 'dining'));
    await _turn();
    expect(cubit.state.pendingFilter?.category, 'dining');
    second.complete(_page(prefix: 'dining-'));
    await newer;
    first.complete(_page(prefix: 'groceries-'));
    await older;
    expect(cubit.state.filter.category, 'dining');
    expect(cubit.state.at(0)?.id, 'dining-0');
    expect(cubit.state.pendingFilter, isNull);
    expect(cubit.state.loading, isFalse);
  });

  test(
    'cache is usable before network and freshness clears after replacement',
    () async {
      final network = Completer<LedgerPage>();
      final reader = _Reader(
        cachedPage: _page(prefix: 'cached-', revision: 'old'),
        request: (_, _, _) => network.future,
      );
      final cubit = HistoryCubit(reader);
      addTearDown(cubit.close);
      final loading = cubit.load();
      await _turn();
      expect(cubit.state.at(0)?.id, 'cached-0');
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.stale, isTrue);
      network.complete(_page(prefix: 'fresh-', revision: 'new'));
      await loading;
      expect(cubit.state.at(0)?.id, 'fresh-0');
      expect(cubit.state.revision, 'new');
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.stale, isFalse);
    },
  );

  test('an expired snapshot reloads the current revision instead of failing '
      'on every retry', () async {
    var current = '1';
    final reader = _Reader(
      request: (filter, cursor, _) async {
        final requested = filter.revision;
        if (requested != null && requested != current) {
          throw const LedgerSnapshotExpired();
        }
        return _page(offset: _offset(cursor), revision: current);
      },
    );
    final cubit = HistoryCubit(reader);
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.revision, '1');
    current = '2';
    cubit.userIsReading = true;
    await cubit.ensurePage(1);
    expect(cubit.state.revision, '2');
    expect(cubit.state.failedPages, isEmpty);
    expect(cubit.state.pendingUpdate, isNull);
    await cubit.ensurePage(1);
    expect(cubit.state.pages[1]?.revision, '2');
    expect(cubit.state.failedPages, isEmpty);
  });

  test('a snapshot that keeps expiring is reported once, not reloaded in a '
      'loop', () async {
    var loads = 0;
    final reader = _Reader(
      request: (filter, cursor, _) async {
        if (filter.revision != null) throw const LedgerSnapshotExpired();
        loads++;
        return _page(offset: _offset(cursor));
      },
    );
    final cubit = HistoryCubit(reader);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.ensurePage(1);
    await cubit.ensurePage(1);
    expect(loads, 2);
    expect(cubit.state.failedPages, {1});
  });

  test('an unreadable cache never prevents the network request', () async {
    final reader = _Reader(
      cacheFailure: const FormatException('cached DTO from an older version'),
    );
    final cubit = HistoryCubit(reader);
    addTearDown(cubit.close);
    await cubit.load();
    expect(reader.requests, hasLength(1));
    expect(cubit.state.at(0)?.id, 'txn-0');
    expect(cubit.state.failed, isFalse);
    expect(cubit.state.stale, isFalse);
  });

  test('an undecodable cached page is discarded as a miss', () async {
    final cache = MemoryCacheStore();
    final client = ApiClient(baseUri: Uri.parse('https://not-used.invalid'));
    addTearDown(cache.close);
    addTearDown(client.close);
    final filter = LedgerFilter();
    final key = 'history:${filter.cacheKey}:first';
    await cache.write(key, {'items': 'not-a-list'});
    final repository = ApiHistoryRepository(client, cache);
    expect(await repository.cached(filter), isNull);
    expect(await cache.read(key), isNull);
  });

  test('refresh failure leaves cache visible and exposes a retry', () async {
    final reader = _Reader(
      cachedPage: _page(prefix: 'cached-'),
      request: (_, _, _) async => throw StateError('offline'),
    );
    final cubit = HistoryCubit(reader);
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.at(0)?.id, 'cached-0');
    expect(cubit.state.stale, isTrue);
    expect(cubit.state.failed, isTrue);
    expect(cubit.state.loading, isFalse);
  });

  test(
    'model pages stay bounded and evicted slots reload with stable IDs',
    () async {
      final reader = _Reader();
      final cubit = HistoryCubit(reader);
      addTearDown(cubit.close);
      await cubit.load();
      for (var page = 1; page < 7; page++) {
        await cubit.loadNext();
        expect(cubit.state.pages.length, lessThanOrEqualTo(5));
      }
      expect(cubit.state.rowCount, 210);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.ids.length, 210);
      expect(cubit.state.at(0), isNull);
      expect(cubit.state.slots.first.id, 'txn-0');
      final metadata = Map<int, String>.of(cubit.state.ids);
      await cubit.ensureIndex(0);
      expect(cubit.state.at(0)?.id, 'txn-0');
      expect(cubit.state.ids, metadata);
      expect(cubit.state.pages.length, 5);
      expect(cubit.state.rowCount, 210);
      final count = reader.requests.length;
      await cubit.ensureIndex(0);
      expect(reader.requests.length, count);
      expect(reader.requests.last.filter.revision, '1');
    },
  );

  test(
    'page failure preserves prior pages and retries exactly that cursor',
    () async {
      var failed = false;
      final reader = _Reader(
        request: (filter, cursor, _) async {
          if (cursor == 'cursor-30' && !failed) {
            failed = true;
            throw StateError('page unavailable');
          }
          return _page(offset: _offset(cursor));
        },
      );
      final cubit = HistoryCubit(reader);
      addTearDown(cubit.close);
      await cubit.load();
      final firstIds = Map<int, String>.of(cubit.state.ids);
      await cubit.loadNext();
      expect(cubit.state.rowCount, 30);
      expect(cubit.state.ids, firstIds);
      expect(cubit.state.failedPages, contains(1));
      expect(cubit.state.failed, isFalse);
      await cubit.loadNext();
      expect(cubit.state.rowCount, 60);
      expect(cubit.state.failedPages, isNot(contains(1)));
      expect(cubit.state.ids.values.toSet().length, 60);
      expect(
        reader.requests.where((request) => request.cursor == 'cursor-30'),
        hasLength(2),
      );
    },
  );

  test('parallel requests for the same page share the loading guard', () async {
    final next = Completer<LedgerPage>();
    final reader = _Reader(
      request: (_, cursor, _) =>
          cursor == null ? Future.value(_page()) : next.future,
    );
    final cubit = HistoryCubit(reader);
    addTearDown(cubit.close);
    await cubit.load();
    final first = cubit.loadNext();
    final duplicate = cubit.loadNext();
    expect(reader.requests, hasLength(2));
    next.complete(_page(offset: 30));
    await Future.wait([first, duplicate]);
    expect(cubit.state.rowCount, 60);
  });

  test(
    'background changes wait for explicit application while user reads',
    () async {
      var changed = false;
      final reader = _Reader(
        request: (_, _, _) async =>
            changed ? _page(prefix: 'new-', revision: '2') : _page(),
      );
      final cubit = HistoryCubit(reader);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.userIsReading = true;
      changed = true;
      await cubit.load(background: true);
      expect(cubit.state.at(0)?.id, 'txn-0');
      expect(cubit.state.revision, '1');
      expect(cubit.state.pendingUpdate?.revision, '2');
      cubit.applyUpdate();
      expect(cubit.state.at(0)?.id, 'new-0');
      expect(cubit.state.revision, '2');
      expect(cubit.state.pendingUpdate, isNull);
    },
  );

  test(
    'background same revision preserves loaded pages and viewport slots',
    () async {
      final cubit = HistoryCubit(_Reader());
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.loadNext();
      await cubit.loadNext();
      final ids = Map<int, String>.of(cubit.state.ids);
      cubit.userIsReading = true;
      await cubit.load(background: true);
      expect(cubit.state.rowCount, 90);
      expect(cubit.state.ids, ids);
      expect(cubit.state.at(65)?.id, 'txn-65');
      expect(cubit.state.pendingUpdate, isNull);
    },
  );

  test('API repository caches parsed first page and rereads it without another request', () async {
    final adapter = SimulationAdapter(
      profile: const NetworkProfile(
        name: 'repository-test',
        firstByteLatency: Duration.zero,
        jitter: Duration.zero,
        bytesPerSecond: 1000000000,
      ),
    );
    final api = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: adapter,
    );
    final cache = MemoryCacheStore();
    addTearDown(api.close);
    addTearDown(cache.close);
    final repository = ApiHistoryRepository(api, cache);
    final filter = LedgerFilter(category: 'dining');
    expect(await repository.cached(filter), isNull);
    final page = await repository.page(filter);
    final requests = adapter.events
        .where((event) => event.phase == 'started')
        .length;
    final cached = (await repository.cached(filter))!;
    expect(
      cached.items.map((item) => item.id),
      page.items.map((item) => item.id),
    );
    expect(cached.revision, page.revision);
    expect(
      adapter.events.where((event) => event.phase == 'started').length,
      requests,
    );
    expect(await repository.cached(LedgerFilter(category: 'shopping')), isNull);
  });
}

void _registerAnchorTests() {
  test('actual status change marks only the retained identity after explicit apply and filter clears it', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final cubit = harness.cubit;
    await cubit.load();
    for (var index = 1; index < 4; index++) {
      await cubit.loadNext();
    }
    final pending = cubit.state.pages.values
        .expand((page) => page.items)
        .firstWhere((entry) => entry.status == EntryStatus.pending);
    cubit.readingAnchorId = pending.id;
    cubit.userIsReading = true;
    expect(cubit.state.updatedIds, isEmpty);
    final mutation = await harness.client.post('/v1/demo/activity');
    expect(mutation['updatedId'], pending.id);
    final added = mutation['addedId'] as String;
    await cubit.load(background: true);
    expect(cubit.state.pendingUpdate, isNotNull);
    expect(cubit.state.updatedIds, isEmpty);
    expect(_entry(cubit.state, pending.id).status, EntryStatus.pending);
    cubit.applyUpdate();
    final updated = _entry(cubit.state, pending.id);
    expect(updated.id, pending.id);
    expect(updated.status, EntryStatus.posted);
    expect(updated.amount, pending.amount);
    expect(updated.kind, pending.kind);
    expect(cubit.state.updatedIds, {pending.id});
    expect(cubit.state.updatedIds, isNot(contains(added)));
    expect(_entry(cubit.state, added).status, EntryStatus.posted);
    await cubit.load(filter: LedgerFilter(category: pending.categoryId));
    expect(cubit.state.ids.values, contains(pending.id));
    expect(cubit.state.updatedIds, isEmpty);
  });

  test('pending next revision keeps current markers scoped to old data and does not replay them on apply', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final cubit = harness.cubit;
    await cubit.load();
    for (var index = 1; index < 4; index++) {
      await cubit.loadNext();
    }
    final pending = cubit.state.pages.values
        .expand((page) => page.items)
        .firstWhere((entry) => entry.status == EntryStatus.pending);
    cubit.readingAnchorId = pending.id;
    cubit.userIsReading = true;
    await harness.client.post('/v1/demo/activity');
    await cubit.load(background: true);
    cubit.applyUpdate();
    expect(cubit.state.updatedIds, {pending.id});
    final appliedRevision = cubit.state.revision;
    final next = await harness.client.post(
      '/v1/demo/activity',
      data: {'changeStatus': false},
    );
    await cubit.load(background: true);
    expect(cubit.state.revision, appliedRevision);
    expect(cubit.state.pendingUpdate?.revision, next['revision']);
    expect(cubit.state.updatedIds, {pending.id});
    expect(cubit.state.ids.values, isNot(contains(next['addedId'])));
    cubit.applyUpdate();
    expect(cubit.state.revision, next['revision']);
    expect(cubit.state.updatedIds, isEmpty);
    expect(_entry(cubit.state, pending.id).status, EntryStatus.posted);
    expect(cubit.state.ids.values, contains(next['addedId']));
  });

  test('new revision preserves a reading anchor past 600 rows and seeks evicted gaps', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final cubit = harness.cubit;
    await cubit.load();
    for (var index = 1; index < 25; index++) {
      await cubit.loadNext();
    }
    expect(cubit.state.pages.length, 5);
    final anchor = cubit.state.ids[600]!;
    final expectedGapEntry = cubit.state.ids[299]!;
    cubit.readingAnchorId = anchor;
    cubit.userIsReading = true;
    await harness.client.post(
      '/v1/demo/activity',
      data: {'changeStatus': false},
    );
    await cubit.load(background: true);
    expect(cubit.state.revision, '1');
    expect(cubit.state.rowCount, 750);
    expect(cubit.state.pendingUpdate?.revision, '2');
    expect(cubit.state.ids[600], anchor);
    cubit.applyUpdate();
    expect(cubit.state.revision, '2');
    expect(cubit.state.pendingUpdate, isNull);
    expect(cubit.state.rowCount, 750);
    expect(cubit.state.at(601)?.id, anchor);
    expect(cubit.state.pages.keys, containsAll([0, 19, 20, 21]));
    expect(cubit.state.pages.length, lessThanOrEqualTo(5));
    expect(cubit.state.at(300), isNull);
    expect(cubit.state.cursors.containsKey(10), isFalse);
    await cubit.ensureIndex(300);
    expect(cubit.state.at(300)?.id, expectedGapEntry);
    expect(cubit.state.ids.values.toSet().length, cubit.state.ids.length);
    expect(cubit.state.pages.length, lessThanOrEqualTo(5));
  });

  test('removed anchor resolves the nearest surviving window with a stable neighbor', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final cubit = harness.cubit;
    await cubit.load();
    for (var page = 1; page < 4; page++) {
      await cubit.loadNext();
    }
    final removed = cubit.state.at(95)!.id;
    final neighbor = cubit.state.at(96)!.id;
    cubit.readingAnchorId = removed;
    cubit.userIsReading = true;
    await harness.client.post(
      '/v1/demo/activity',
      data: {'changeStatus': false, 'removeId': removed},
    );
    await cubit.load(background: true);
    expect(cubit.state.at(95)?.id, removed);
    cubit.applyUpdate();
    expect(cubit.state.ids.values, isNot(contains(removed)));
    expect(cubit.state.at(96)?.id, neighbor);
    expect(cubit.state.pages.keys, contains(3));
    expect(cubit.state.pages.length, lessThanOrEqualTo(5));
  });

  test('filter preserves an included identity and starts at zero when it excludes it', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final cubit = harness.cubit;
    await cubit.load();
    final anchor = cubit.state.at(12)!;
    cubit.readingAnchorId = anchor.id;
    await cubit.load(filter: LedgerFilter(category: anchor.categoryId));
    expect(cubit.state.ids.values, contains(anchor.id));
    final excluded = anchor.categoryId == 'dining' ? 'groceries' : 'dining';
    await cubit.load(filter: LedgerFilter(category: excluded));
    expect(cubit.state.filter.category, excluded);
    expect(cubit.state.ids.values, isNot(contains(anchor.id)));
    expect(cubit.state.rowCount, 30);
    expect(cubit.state.pages.keys, [0]);
  });

  test(
    'obsolete anchor window cannot apply after a newer filter completes',
    () async {
      final delayed = Completer<LedgerPage>();
      var changed = false;
      final reader = _Reader(
        request: (filter, cursor, _) async => _page(
          offset: _offset(cursor),
          prefix: filter.category == 'dining' ? 'dining-' : 'txn-',
          revision: filter.category == 'dining'
              ? '3'
              : changed
              ? '2'
              : '1',
        ),
        resolveAround: (filter, _, _) => filter.category == 'dining'
            ? Future.value(_page(prefix: 'dining-', revision: '3'))
            : delayed.future,
      );
      final cubit = HistoryCubit(reader);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.loadNext();
      await cubit.loadNext();
      cubit.readingAnchorId = cubit.state.at(65)!.id;
      cubit.userIsReading = true;
      changed = true;
      final obsolete = cubit.load(background: true);
      await _turn();
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.revision, '1');
      await cubit.load(filter: LedgerFilter(category: 'dining'));
      delayed.complete(_page(offset: 60, revision: '2'));
      await obsolete;
      cubit.applyUpdate();
      expect(cubit.state.filter.category, 'dining');
      expect(cubit.state.revision, '3');
      expect(cubit.state.pendingUpdate, isNull);
      expect(cubit.state.at(0)?.id, 'dining-0');
    },
  );
}

LedgerEntry _entry(HistoryState state, String id) => state.pages.values
    .expand((page) => page.items)
    .singleWhere((entry) => entry.id == id);

final class _Harness {
  _Harness() {
    final adapter = SimulationAdapter(
      api: DemoApi(now: () => DateTime.utc(2026, 10, 16, 15)),
      profile: const NetworkProfile(
        name: 'anchor-contract',
        firstByteLatency: Duration.zero,
        jitter: Duration.zero,
        bytesPerSecond: 1000000000,
      ),
    );
    client = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: adapter,
    );
    cache = MemoryCacheStore();
    cubit = HistoryCubit(ApiHistoryRepository(client, cache));
  }
  late final ApiClient client;
  late final CacheStore cache;
  late final HistoryCubit cubit;
  Future<void> close() async {
    await cubit.close();
    client.close();
    await cache.close();
  }
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);
int _offset(String? cursor) =>
    cursor == null ? 0 : int.parse(cursor.substring(7));

LedgerPage _page({
  int offset = 0,
  String prefix = 'txn-',
  String revision = '1',
}) => LedgerPage(
  items: List.generate(
    30,
    (index) => LedgerEntry(
      id: '$prefix${offset + index}',
      title: 'Операция ${offset + index}',
      subtitle: 'Продукты',
      amount: Money(10000 + offset + index),
      occurredAt: DateTime.utc(
        2026,
        10,
        16,
      ).subtract(Duration(minutes: offset + index)),
      categoryId: 'groceries',
      merchantId: 'market',
      accountId: 'main',
      kind: EntryKind.expense,
      status: EntryStatus.posted,
    ),
  ),
  total: 210,
  totalAmount: const Money(2121945),
  revision: revision,
  startIndex: offset,
  startCursor: 'cursor-$offset',
  prevCursor: offset > 0 ? 'cursor-${offset - 30}' : null,
  nextCursor: offset + 30 < 210 ? 'cursor-${offset + 30}' : null,
);

final class _Request {
  const _Request(this.filter, this.cursor);
  final LedgerFilter filter;
  final String? cursor;
}

final class _Reader implements HistoryReader {
  _Reader({
    this.cachedPage,
    this.cacheFailure,
    this.request,
    this.resolveAround,
  });
  final LedgerPage? cachedPage;
  final Object? cacheFailure;
  final Future<LedgerPage> Function(LedgerFilter, String?, int)? request;
  final Future<LedgerPage> Function(LedgerFilter, String, int)? resolveAround;
  final List<_Request> requests = [];
  @override
  Future<LedgerPage?> cached(LedgerFilter filter, {String? cursor}) async {
    if (cacheFailure case final failure?) throw failure;
    return cachedPage;
  }

  @override
  Future<LedgerPage> page(
    LedgerFilter filter, {
    String? cursor,
    int limit = 30,
    int? startIndex,
  }) {
    requests.add(_Request(filter, cursor));
    final effectiveCursor =
        cursor ?? (startIndex == null ? null : 'cursor-$startIndex');
    return request?.call(filter, effectiveCursor, limit) ??
        Future.value(_page(offset: _offset(effectiveCursor)));
  }

  @override
  Future<LedgerPage> around(
    LedgerFilter filter,
    String anchorId, {
    int fallbackIndex = 0,
  }) async {
    if (resolveAround != null) {
      return resolveAround!(filter, anchorId, fallbackIndex);
    }
    final index = int.tryParse(anchorId.split('-').last) ?? fallbackIndex;
    return _page(offset: (index ~/ 30) * 30);
  }
}
