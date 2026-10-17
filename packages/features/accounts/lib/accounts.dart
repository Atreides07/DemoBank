library;

export 'src/account_management.dart';
export 'src/account_operation_cubit.dart';
export 'src/account_operation_journal.dart';
export 'src/account_view.dart';

import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

final class ApiAccountsRepository implements AccountsReader {
  ApiAccountsRepository(this._api, this._cache);
  final ApiClient _api;
  final CacheStore _cache;
  @override
  Future<List<Account>?> cachedAccounts() async {
    final entry = await _cache.read('accounts');
    return entry == null ? null : _decode(entry.value);
  }

  List<Account> _decode(Map<String, dynamic> value) => decodeAccounts(value);
  @override
  Future<List<Account>> accounts() async {
    final json = await _api.get('/v1/accounts');
    await _cache.write('accounts', json);
    return _decode(json);
  }
}

final class AccountsState {
  const AccountsState({
    this.accounts = const [],
    this.loading = true,
    this.error,
  });
  final List<Account> accounts;
  final bool loading;
  final String? error;

  /// Compatibility total for the primary RUB header. Other currencies are
  /// deliberately presented separately through [balances].
  Money get balance => balanceFor('RUB');

  Money balanceFor(String currency) => accounts
      .where((account) => account.balance.currency == currency)
      .fold(
        Money(0, currency: currency),
        (sum, account) => sum + account.balance,
      );

  List<Money> get balances {
    final totals = <String, Money>{};
    for (final account in accounts) {
      final currency = account.balance.currency;
      totals[currency] =
          (totals[currency] ?? Money(0, currency: currency)) + account.balance;
    }
    final currencies = totals.keys.toList()..sort();
    return List.unmodifiable(currencies.map((currency) => totals[currency]!));
  }
}

final class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this.reader) : super(const AccountsState());
  final AccountsReader reader;
  int _epoch = 0;
  Future<void> load() async {
    final epoch = ++_epoch;
    emit(AccountsState(accounts: state.accounts, loading: true));
    try {
      final cached = await reader.cachedAccounts();
      if (isClosed || epoch != _epoch) return;
      if (cached != null) emit(AccountsState(accounts: cached, loading: true));
      final accounts = await reader.accounts();
      if (!isClosed && epoch == _epoch) {
        emit(
          AccountsState(accounts: List.unmodifiable(accounts), loading: false),
        );
      }
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(
          AccountsState(
            accounts: state.accounts,
            loading: false,
            error: 'Не удалось обновить счета. Доступны сохранённые данные.',
          ),
        );
      }
    }
  }
}
