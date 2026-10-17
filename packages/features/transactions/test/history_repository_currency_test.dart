import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:transactions/transactions.dart';

Map<String, dynamic> _page(String currency) => {
  'currency': currency,
  'items': <Object?>[],
  'total': 0,
  'totalMinor': 0,
  'revision': '1',
  'startIndex': 0,
};

void main() {
  test(
    'history cache is currency scoped and insensitive to account ordering',
    () async {
      final cache = MemoryCacheStore();
      final client = ApiClient(baseUri: Uri.parse('https://not-used.invalid'));
      addTearDown(cache.close);
      addTearDown(client.close);
      final repository = ApiHistoryRepository(client, cache);
      final filter = LedgerFilter(
        accounts: ['savings', 'main'],
        currency: 'USD',
      );
      await cache.write('history:${filter.cacheKey}:first', _page('USD'));
      final restored = (await repository.cached(
        filter.copyWith(accounts: ['main', 'savings']),
      ))!;
      expect(restored.totalAmount, const Money(0, currency: 'USD'));
      expect(await repository.cached(filter.copyWith(currency: 'RUB')), isNull);
    },
  );

  test('history refuses a cached response with another currency', () async {
    final cache = MemoryCacheStore();
    final client = ApiClient(baseUri: Uri.parse('https://not-used.invalid'));
    addTearDown(cache.close);
    addTearDown(client.close);
    final filter = LedgerFilter(currency: 'USD');
    await cache.write('history:${filter.cacheKey}:first', _page('RUB'));
    await expectLater(
      ApiHistoryRepository(client, cache).cached(filter),
      throwsFormatException,
    );
  });

  test(
    'page, indexed seek and anchor send currency and preserve window metadata',
    () async {
      final requests = <Map<String, String>>[];
      final backend = DemoApi(
        routes: [
          (request) async {
            if (request.path != '/transactions') return null;
            final query = request.query;
            requests.add(Map.of(query));
            final start = query['anchor'] != null
                ? 60
                : int.parse(query['at'] ?? '0');
            return SimulatedResponse({
              'currency': 'USD',
              'total': 120,
              'totalMinor': 1200000,
              'revision': 'usd-1',
              'startIndex': start,
              'startCursor': 'cursor-$start',
              'prevCursor': start > 0 ? 'cursor-${start - 30}' : null,
              'nextCursor': start + 30 < 120 ? 'cursor-${start + 30}' : null,
              'items': List.generate(
                30,
                (offset) => {
                  'id': 'usd-entry-${start + offset}',
                  'title': 'Покупка',
                  'subtitle': '',
                  'amountMinor': 10000,
                  'currency': 'USD',
                  'occurredAt': '2026-10-16T12:00:00.000Z',
                  'categoryId': 'shopping',
                  'merchantId': 'shop',
                  'accountId': 'usd-account',
                  'kind': 'expense',
                  'status': 'posted',
                },
              ),
            });
          },
        ],
      );
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: SimulationAdapter(
          api: backend,
          profile: const NetworkProfile(
            name: 'currency-repository',
            firstByteLatency: Duration.zero,
            jitter: Duration.zero,
            bytesPerSecond: 1000000000,
          ),
        ),
      );
      final cache = MemoryCacheStore();
      addTearDown(client.close);
      addTearDown(cache.close);
      final repository = ApiHistoryRepository(client, cache);
      final filter = LedgerFilter(currency: 'USD');
      final first = await repository.page(filter);
      expect(first.totalAmount.currency, 'USD');
      expect(
        first.items.every((entry) => entry.amount.currency == 'USD'),
        isTrue,
      );
      final versioned = filter.copyWith(revision: first.revision);
      final anchored = await repository.around(
        versioned,
        'usd-entry-61',
        fallbackIndex: 61,
      );
      expect(anchored.totalAmount.currency, 'USD');
      expect(anchored.items.any((entry) => entry.id == 'usd-entry-61'), isTrue);
      expect(anchored.revision, first.revision);
      expect(anchored.startIndex, 60);
      expect(anchored.startCursor, 'cursor-60');
      expect(anchored.prevCursor, 'cursor-30');
      expect(anchored.nextCursor, 'cursor-90');
      final indexed = await repository.page(versioned, startIndex: 60);
      expect(indexed.startIndex, 60);
      expect(indexed.items.first.id, 'usd-entry-60');
      expect(requests.every((query) => query['currency'] == 'USD'), isTrue);
      expect(requests[1]['anchor'], 'usd-entry-61');
      expect(requests[1]['near'], '61');
      expect(requests[1]['revision'], 'usd-1');
      expect(requests[2]['at'], '60');
    },
  );
}
