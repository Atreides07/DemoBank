import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:spending_analytics/spending_analytics.dart';

void main() {
  test(
    'cached analytics is shown while fresh aggregates are pending',
    () async {
      final fresh = Completer<SpendingSummary>();
      final cubit = AnalyticsCubit(
        _Reader(
          cachedValue: _summary(100, 'cached'),
          request: (_) => fresh.future,
        ),
        filter: LedgerFilter(category: 'groceries'),
      );
      addTearDown(cubit.close);
      final loading = cubit.load();
      await _turn();
      expect(cubit.state.summary?.total.minor, 100);
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.stale, isTrue);
      fresh.complete(_summary(200, 'fresh'));
      await loading;
      expect(cubit.state.summary?.revision, 'fresh');
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.stale, isFalse);
    },
  );

  test(
    'analytics refresh error retains coherent cached totals and categories',
    () async {
      final cached = _summary(100, 'cached');
      final cubit = AnalyticsCubit(
        _Reader(
          cachedValue: cached,
          request: (_) async => throw StateError('offline'),
        ),
        filter: LedgerFilter(category: 'groceries'),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.summary, same(cached));
      expect(cubit.state.filter.category, 'groceries');
      expect(cubit.state.stale, isTrue);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.failed, isTrue);
    },
  );

  test(
    'out-of-order filter results cannot replace the current revision',
    () async {
      final older = Completer<SpendingSummary>();
      final newer = Completer<SpendingSummary>();
      final cubit = AnalyticsCubit(
        _Reader(
          request: (filter) =>
              filter.category == 'groceries' ? older.future : newer.future,
        ),
        filter: LedgerFilter(),
      );
      addTearDown(cubit.close);
      final first = cubit.load(filter: LedgerFilter(category: 'groceries'));
      await _turn();
      final second = cubit.load(filter: LedgerFilter(category: 'dining'));
      await _turn();
      expect(cubit.state.pendingFilter?.category, 'dining');
      newer.complete(_summary(200, 'newer'));
      await second;
      older.complete(_summary(100, 'older'));
      await first;
      expect(cubit.state.filter.category, 'dining');
      expect(cubit.state.summary?.total.minor, 200);
      expect(cubit.state.summary?.revision, 'newer');
      expect(cubit.state.pendingFilter, isNull);
    },
  );

  test('obsolete error cannot hide a successful newer result', () async {
    final older = Completer<SpendingSummary>();
    final cubit = AnalyticsCubit(
      _Reader(
        request: (filter) => filter.category == 'groceries'
            ? older.future
            : Future.value(_summary(200, 'newer')),
      ),
      filter: LedgerFilter(),
    );
    addTearDown(cubit.close);
    final first = cubit.load(filter: LedgerFilter(category: 'groceries'));
    await _turn();
    await cubit.load(filter: LedgerFilter(category: 'dining'));
    older.completeError(StateError('stale request failed'));
    await first;
    expect(cubit.state.summary?.revision, 'newer');
    expect(cubit.state.failed, isFalse);
  });

  test('closing the state scope ignores a late result', () async {
    final pending = Completer<SpendingSummary>();
    final cubit = AnalyticsCubit(
      _Reader(request: (_) => pending.future),
      filter: LedgerFilter(),
    );
    final loading = cubit.load();
    await _turn();
    await cubit.close();
    pending.complete(_summary(100, 'late'));
    await loading;
    expect(cubit.state.summary, isNull);
  });

  test(
    'API aggregates equal every page of parsed expense detail and cache is filter scoped',
    () async {
      final adapter = SimulationAdapter(
        profile: const NetworkProfile(
          name: 'analytics-contract',
          firstByteLatency: Duration.zero,
          jitter: Duration.zero,
          bytesPerSecond: 1000000000,
        ),
      );
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: adapter,
      );
      final cache = MemoryCacheStore();
      addTearDown(client.close);
      addTearDown(cache.close);
      final repository = ApiAnalyticsRepository(client, cache);
      final filter = LedgerFilter(
        from: DateTime.utc(2026, 9, 30, 21),
        to: DateTime.utc(2026, 10, 16, 21),
        accounts: const ['main'],
      );
      expect(await repository.cached(filter), isNull);
      final summary = await repository.summary(filter);
      expect(summary.total.minor, greaterThan(0));
      expect(
        summary.categories.fold<int>(
          0,
          (sum, point) => sum + point.amount.minor,
        ),
        summary.total.minor,
      );
      expect(
        summary.merchants.fold<int>(
          0,
          (sum, point) => sum + point.amount.minor,
        ),
        summary.total.minor,
      );
      expect(
        summary.timeline.fold<int>(0, (sum, point) => sum + point.amount.minor),
        summary.total.minor,
      );
      var total = 0;
      final ids = <String>{};
      String? cursor;
      do {
        final page = decodeLedgerPage(
          await client.get(
            '/v1/transactions',
            query: {
              ...filter
                  .copyWith(kind: EntryKind.expense, revision: summary.revision)
                  .toQuery(),
              'limit': 30,
              'cursor': ?cursor,
            },
          ),
        );
        expect(page.revision, summary.revision);
        expect(page.totalAmount.minor, summary.total.minor);
        for (final entry in page.items) {
          expect(entry.status, EntryStatus.posted);
          expect(entry.kind, EntryKind.expense);
          expect(ids.add(entry.id), isTrue);
          total += entry.amount.minor;
        }
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(total, summary.total.minor);
      expect(ids.length, summary.count);
      final requestCount = adapter.events
          .where((event) => event.phase == 'started')
          .length;
      final cached = (await repository.cached(filter))!;
      expect(cached.total.minor, total);
      expect(cached.revision, summary.revision);
      expect(
        adapter.events.where((event) => event.phase == 'started').length,
        requestCount,
      );
      expect(
        await repository.cached(filter.copyWith(category: 'dining')),
        isNull,
      );
      final category = summary.categories.first;
      final narrowed = await repository.summary(
        filter.copyWith(category: category.id, revision: summary.revision),
      );
      expect(narrowed.total.minor, category.amount.minor);
    },
  );
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

SpendingSummary _summary(int total, String revision) => SpendingSummary(
  total: Money(total),
  refunds: const Money(0),
  previous: const Money(0),
  count: 1,
  revision: revision,
  categories: [
    AggregatePoint(
      id: 'groceries',
      label: 'Продукты',
      amount: Money(total),
      count: 1,
    ),
  ],
  merchants: [
    AggregatePoint(
      id: 'market',
      label: 'Магазин',
      amount: Money(total),
      count: 1,
    ),
  ],
  timeline: [
    AggregatePoint(id: 'day', label: '16.10', amount: Money(total), count: 1),
  ],
  comparisonFrom: DateTime.utc(2026, 9),
  comparisonTo: DateTime.utc(2026, 10),
);

final class _Reader implements AnalyticsReader {
  const _Reader({this.cachedValue, required this.request});
  final SpendingSummary? cachedValue;
  final Future<SpendingSummary> Function(LedgerFilter) request;
  @override
  Future<SpendingSummary?> cached(LedgerFilter filter) async => cachedValue;
  @override
  Future<SpendingSummary> summary(LedgerFilter filter) => request(filter);
}
