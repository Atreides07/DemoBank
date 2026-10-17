import 'package:accounts/accounts.dart';
import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

Account _account(String id, int amount, String currency) => Account(
  id: id,
  name: id,
  balance: Money(amount, currency: currency),
  lastDigits: '1234',
  kind: 'debit',
);

void main() {
  test('balances are grouped immutably and never add different currencies', () {
    final state = AccountsState(
      accounts: [
        _account('rub', 10000, 'RUB'),
        _account('usd1', 10001, 'USD'),
        _account('usd2', 999, 'USD'),
        _account('eur', 17, 'EUR'),
      ],
      loading: false,
    );
    expect(state.balance, const Money(10000));
    expect(state.balanceFor('USD'), const Money(11000, currency: 'USD'));
    expect(state.balanceFor('GBP'), const Money(0, currency: 'GBP'));
    expect(state.balances, [
      const Money(17, currency: 'EUR'),
      const Money(10000),
      const Money(11000, currency: 'USD'),
    ]);
    expect(() => state.balances.clear(), throwsUnsupportedError);
  });

  test(
    'cached account DTO uses data mapper and preserves currency without transport',
    () async {
      final cache = MemoryCacheStore();
      final client = ApiClient(baseUri: Uri.parse('https://not-used.invalid'));
      addTearDown(cache.close);
      addTearDown(client.close);
      await cache.write('accounts', {
        'accounts': [
          {
            'id': 'usd',
            'name': 'Dollar',
            'balanceMinor': 120099,
            'currency': 'USD',
          },
        ],
      });
      final accounts = (await ApiAccountsRepository(
        client,
        cache,
      ).cachedAccounts())!;
      expect(accounts.single.balance, const Money(120099, currency: 'USD'));
      expect(() => accounts.clear(), throwsUnsupportedError);
    },
  );
}
