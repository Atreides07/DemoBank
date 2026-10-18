import 'package:bank_core/bank_core.dart';
import 'package:test/test.dart';

void main() {
  test('money arithmetic stays in exact minor units', () {
    expect(const Money(10) + const Money(20), const Money(30));
    expect(const Money(100) - const Money(1), const Money(99));
    expect(
      () => const Money(1) + const Money(1, currency: 'USD'),
      throwsArgumentError,
    );
  });
  test('reporting periods use half-open Moscow midnight', () {
    final month = ReportingPeriod.month(DateTime(2026, 10, 16));
    expect(month.from, DateTime.utc(2026, 9, 30, 21));
    expect(month.to, DateTime.utc(2026, 10, 16, 21));
    final leap = ReportingPeriod.custom(
      DateTime(2024, 2, 28),
      DateTime(2024, 2, 29),
    );
    expect(leap.to, DateTime.utc(2024, 2, 29, 21));
  });
  test('filters carry identities and isolate caller list mutations', () {
    final accounts = ['main'];
    final filter = LedgerFilter(accounts: accounts, category: 'groceries');
    accounts.clear();
    expect(filter.accounts, ['main']);
    expect(filter.copyWith(clearCategory: true).category, isNull);
    expect(filter.currency, 'RUB');
    expect(filter.copyWith(currency: 'USD').currency, 'USD');
    expect(filter.copyWith(category: 'dining').currency, 'RUB');
  });
  test(
    'filter value equality uses unordered membership, instants and currency',
    () {
      final first = LedgerFilter(
        accounts: ['savings', 'main'],
        currency: 'USD',
        from: DateTime.parse('2026-10-01T00:00:00+03:00'),
      );
      final second = LedgerFilter(
        accounts: ['main', 'savings', 'main'],
        currency: 'USD',
        from: DateTime.utc(2026, 9, 30, 21),
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(first.copyWith(currency: 'RUB')));
      expect(first, isNot(first.copyWith(revision: '2')));
      expect(first.copyWith(category: 'dining').currency, 'USD');
    },
  );
}
