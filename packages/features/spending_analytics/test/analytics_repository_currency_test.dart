import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:spending_analytics/spending_analytics.dart';

Map<String, dynamic> _summary(String currency) => {
  'currency': currency,
  'totalMinor': 0,
  'refundMinor': 0,
  'previousTotalMinor': 0,
  'count': 0,
  'revision': '1',
  'categories': <Object?>[],
  'merchants': <Object?>[],
  'timeline': <Object?>[],
  'comparisonFrom': '2026-09-01T00:00:00.000Z',
  'comparisonTo': '2026-10-01T00:00:00.000Z',
};

void main() {
  test(
    'analytics cache uses canonical membership and separates currencies',
    () async {
      final cache = MemoryCacheStore();
      final client = ApiClient(baseUri: Uri.parse('https://not-used.invalid'));
      addTearDown(cache.close);
      addTearDown(client.close);
      final repository = ApiAnalyticsRepository(client, cache);
      final filter = LedgerFilter(
        currency: 'USD',
        accounts: ['savings', 'main'],
      );
      await cache.write('analytics:${filter.cacheKey}', _summary('USD'));
      final restored = (await repository.cached(
        filter.copyWith(accounts: ['main', 'savings']),
      ))!;
      expect(restored.total, const Money(0, currency: 'USD'));
      expect(restored.previous.currency, 'USD');
      expect(restored.refunds.currency, 'USD');
      expect(await repository.cached(filter.copyWith(currency: 'RUB')), isNull);
      await cache.write('analytics:${filter.cacheKey}', _summary('RUB'));
      await expectLater(repository.cached(filter), throwsFormatException);
    },
  );

  test(
    'real repository preserves selected response currency throughout aggregate models',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: SimulationAdapter(
          profile: const NetworkProfile(
            name: 'analytics-currency',
            firstByteLatency: Duration.zero,
            jitter: Duration.zero,
            bytesPerSecond: 1000000000,
          ),
        ),
      );
      final cache = MemoryCacheStore();
      addTearDown(client.close);
      addTearDown(cache.close);
      final repository = ApiAnalyticsRepository(client, cache);
      final summary = await repository.summary(LedgerFilter(currency: 'USD'));
      expect(summary.total.currency, 'USD');
      expect(summary.refunds.currency, 'USD');
      expect(summary.previous.currency, 'USD');
      for (final point in [
        ...summary.categories,
        ...summary.merchants,
        ...summary.timeline,
      ]) {
        expect(point.amount.currency, 'USD');
      }
    },
  );
}
