import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:test/test.dart';

void main() {
  test(
    'query carries currency, UTC boundaries, all identities and canonical account membership',
    () {
      final filter = LedgerFilter(
        from: DateTime.parse('2026-10-01T00:00:00+03:00'),
        to: DateTime.utc(2026, 10, 16, 21),
        category: 'кафе & еда',
        merchant: 'cafe=one',
        accounts: const ['savings', 'main', 'main'],
        kind: EntryKind.expense,
        revision: 'revision:7',
        currency: 'USD',
      );
      expect(filter.toQuery(), {
        'currency': 'USD',
        'from': '2026-09-30T21:00:00.000Z',
        'to': '2026-10-16T21:00:00.000Z',
        'category': 'кафе & еда',
        'merchant': 'cafe=one',
        'accounts': 'main,savings',
        'kind': 'expense',
        'revision': 'revision:7',
      });
      expect(
        Uri.splitQueryString(filter.cacheKey),
        filter.toQuery().map((key, value) => MapEntry(key, value.toString())),
      );
    },
  );

  test(
    'same filter in another account order or time zone reuses one cache key',
    () {
      final first = LedgerFilter(
        accounts: ['savings', 'main'],
        from: DateTime.parse('2026-10-01T00:00:00+03:00'),
      );
      final second = LedgerFilter(
        accounts: ['main', 'savings', 'main'],
        from: DateTime.utc(2026, 9, 30, 21),
      );
      expect(first.cacheKey, second.cacheKey);
      expect(first.toQuery()['accounts'], 'main,savings');
    },
  );

  test(
    'escaped delimiters, currency, revision and scope avoid cache collisions',
    () {
      final embedded = LedgerFilter(category: 'food&merchant=cafe');
      final separate = LedgerFilter(category: 'food', merchant: 'cafe');
      expect(embedded.cacheKey, isNot(separate.cacheKey));
      final filter = LedgerFilter(accounts: ['main'], currency: 'USD');
      expect(filter.cacheKey, isNot(filter.copyWith(currency: 'RUB').cacheKey));
      expect(filter.cacheKey, isNot(filter.copyWith(revision: '2').cacheKey));
      expect(
        filter.cacheKey,
        isNot(filter.copyWith(accounts: ['savings']).cacheKey),
      );
      expect(LedgerFilter().toQuery(), {'currency': 'RUB'});
    },
  );
}
