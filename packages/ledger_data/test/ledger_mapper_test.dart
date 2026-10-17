import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:test/test.dart';

Map<String, dynamic> _entry({String? currency = 'USD'}) => {
  'id': 'entry-1',
  'title': 'Кофе',
  'subtitle': 'Покупка',
  'amountMinor': 12345,
  'currency': ?currency,
  'occurredAt': '2026-10-16T12:00:00.000Z',
  'categoryId': 'dining',
  'merchantId': 'cafe',
  'accountId': 'usd-account',
  'kind': 'expense',
  'status': 'posted',
};

Map<String, dynamic> _point({String? currency}) => {
  'id': 'dining',
  'label': 'Кафе',
  'amountMinor': 12345,
  'count': 1,
  'currency': ?currency,
  'from': '2026-10-15T21:00:00.000Z',
  'to': '2026-10-16T21:00:00.000Z',
};

Map<String, dynamic> _page({
  String currency = 'USD',
  String? itemCurrency = 'USD',
}) => {
  'currency': currency,
  'items': [_entry(currency: itemCurrency)],
  'total': 120,
  'totalMinor': 12345,
  'revision': 7,
  'startIndex': 60,
  'startCursor': 'at-sixty',
  'prevCursor': 'at-thirty',
  'nextCursor': 'at-ninety',
};

Map<String, dynamic> _summary({String currency = 'USD'}) => {
  'currency': currency,
  'totalMinor': 12345,
  'refundMinor': 67,
  'previousTotalMinor': 10000,
  'count': 1,
  'revision': 'revision-7',
  'categories': [_point()],
  'merchants': [_point()],
  'timeline': [_point()],
  'comparisonFrom': '2026-09-01T00:00:00.000Z',
  'comparisonTo': '2026-10-01T00:00:00.000Z',
};

void main() {
  test(
    'account and transaction money preserve their declared currencies exactly',
    () {
      final account = decodeAccount({
        'id': 'usd-account',
        'name': 'Долларовый счёт',
        'balanceMinor': 50123,
        'currency': 'USD',
        'lastDigits': '1234',
        'kind': 'debit',
      });
      expect(account.balance, const Money(50123, currency: 'USD'));
      expect(
        decodeLedgerEntry(_entry()).amount,
        const Money(12345, currency: 'USD'),
      );
      expect(
        decodeLedgerEntry(_entry(currency: 'EUR')).amount,
        const Money(12345, currency: 'EUR'),
      );
    },
  );

  test(
    'ledger page retains all anchor/window fields and inherits its currency',
    () {
      final page = decodeLedgerPage(_page(itemCurrency: null));
      expect(page.totalAmount, const Money(12345, currency: 'USD'));
      expect(page.items.single.amount.currency, 'USD');
      expect(page.revision, '7');
      expect(page.total, 120);
      expect(page.startIndex, 60);
      expect(page.startCursor, 'at-sixty');
      expect(page.prevCursor, 'at-thirty');
      expect(page.nextCursor, 'at-ninety');
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'summary totals, refunds, comparison and every aggregate share response currency',
    () {
      final summary = decodeSpendingSummary(_summary());
      expect(summary.total, const Money(12345, currency: 'USD'));
      expect(summary.refunds, const Money(67, currency: 'USD'));
      expect(summary.previous, const Money(10000, currency: 'USD'));
      for (final point in [
        ...summary.categories,
        ...summary.merchants,
        ...summary.timeline,
      ]) {
        expect(point.amount, const Money(12345, currency: 'USD'));
        expect(point.from, DateTime.utc(2026, 10, 15, 21));
        expect(point.to, DateTime.utc(2026, 10, 16, 21));
      }
      expect(summary.comparisonFrom, DateTime.utc(2026, 9));
      expect(summary.comparisonTo, DateTime.utc(2026, 10));
      expect(() => summary.categories.clear(), throwsUnsupportedError);
      expect(
        decodeAggregatePoint(_point(currency: 'GBP')).amount.currency,
        'GBP',
      );
    },
  );

  test(
    'missing currency is a broken API contract rather than a RUB fallback',
    () {
      final page = _page()..remove('currency');
      final summary = _summary()..remove('currency');
      expect(() => decodeLedgerPage(page), throwsFormatException);
      expect(() => decodeSpendingSummary(summary), throwsFormatException);
      expect(
        () => decodeLedgerEntry(_entry(currency: null)),
        throwsFormatException,
      );
      expect(
        () => decodeAccount({'id': 'a', 'name': 'A', 'balanceMinor': 100}),
        throwsFormatException,
      );
    },
  );

  test(
    'conflicting child currencies cannot masquerade as a coherent response',
    () {
      expect(
        () => decodeLedgerPage(_page(itemCurrency: 'RUB')),
        throwsFormatException,
      );
      final summary = _summary()..['categories'] = [_point(currency: 'EUR')];
      expect(() => decodeSpendingSummary(summary), throwsFormatException);
    },
  );

  test('non-integral monetary DTO and missing revision are rejected', () {
    final page = _page()..remove('revision');
    expect(() => decodeLedgerPage(page), throwsFormatException);
    expect(
      () => decodeLedgerEntry(_entry()..['amountMinor'] = 123.45),
      throwsFormatException,
    );
  });

  test('every malformed field is a FormatException, never a TypeError', () {
    for (final (field, value) in [
      ('id', null),
      ('title', 42),
      ('occurredAt', 'yesterday'),
      ('kind', 'chargeback'),
      ('status', null),
    ]) {
      expect(
        () => decodeLedgerEntry(_entry()..[field] = value),
        throwsFormatException,
        reason: field,
      );
    }
    expect(
      () => decodeLedgerPage(_page()..['items'] = ['not an object']),
      throwsFormatException,
    );
    expect(
      () => decodeAccountProfile({'currency': 'RUB', 'id': 7}),
      throwsFormatException,
    );
  });
}
