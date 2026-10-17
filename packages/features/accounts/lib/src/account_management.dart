import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

final class ApiAccountManagement implements AccountManagement {
  ApiAccountManagement(this.api, this.cache);
  final ApiClient api;
  final CacheStore cache;
  final _cancellation = RequestCancellation();
  String _path(String id) => '/v1/accounts/${Uri.encodeComponent(id)}';
  String _key(String id) => 'account-profile:$id';
  @override
  Future<AccountProfile?> cachedProfile(String accountId) async {
    final entry = await cache.read(_key(accountId));
    return entry == null ? null : decodeAccountProfile(entry.value);
  }

  @override
  Future<AccountProfile> profile(String accountId) async {
    final json = await api.get(
      '${_path(accountId)}/profile',
      cancellation: _cancellation,
    );
    await cache.write(_key(accountId), json);
    return decodeAccountProfile(json);
  }

  @override
  Future<AccountProfile> update(
    String accountId,
    AccountPreferences preferences,
  ) async {
    final json = await api.post(
      '${_path(accountId)}/preferences',
      data: encodeAccountPreferences(preferences),
      cancellation: _cancellation,
    );
    await cache.write(_key(accountId), json);
    return decodeAccountProfile(json);
  }

  @override
  Future<AccountOperationResult> execute(AccountOperation operation) async {
    try {
      final json = await api.post(
        '${_path(operation.accountId)}/operations',
        cancellation: _cancellation,
        data: {
          'requestId': operation.requestId,
          'kind': operation.kind.name,
          'amountMinor': operation.amount.minor,
          'currency': operation.amount.currency,
          if (operation.destinationId != null)
            'destinationId': operation.destinationId,
        },
      );
      return AccountOperationResult(
        id: json['id'] as String,
        requestId: json['requestId'] as String,
        amount: Money(
          json['amountMinor'] as int,
          currency: json['currency'] as String,
        ),
      );
    } on ApiFailure catch (error) {
      if (error.statusCode == 422) {
        throw AccountOperationRejected(error.message);
      }
      rethrow;
    }
  }

  @override
  Future<List<AccountRecipient>> recipients(String accountId) async {
    final json = await api.get(
      '${_path(accountId)}/recipients',
      cancellation: _cancellation,
    );
    return List.unmodifiable(
      (json['items'] as List).map((raw) {
        final r = raw as Map;
        return AccountRecipient(
          id: r['id'] as String,
          name: r['name'] as String,
          bank: r['bank'] as String,
          phone: r['phone'] as String,
        );
      }),
    );
  }

  @override
  void close() => _cancellation.cancel();
}

final class AccountManagementState {
  const AccountManagementState({
    this.profile,
    this.loading = false,
    this.saving = false,
    this.stale = false,
    this.error,
  });
  final AccountProfile? profile;
  final bool loading;
  final bool saving;
  final bool stale;
  final String? error;
}

final class AccountManagementCubit extends Cubit<AccountManagementState> {
  AccountManagementCubit(this.reader, this.accountId)
    : super(const AccountManagementState());
  final AccountManagement reader;
  final String accountId;
  int _epoch = 0;
  Future<void> load() async {
    final epoch = ++_epoch;
    emit(AccountManagementState(profile: state.profile, loading: true));
    try {
      if (state.profile == null) {
        final cached = await reader.cachedProfile(accountId);
        if (isClosed || epoch != _epoch) return;
        if (cached != null) {
          emit(
            AccountManagementState(profile: cached, loading: true, stale: true),
          );
        }
      }
      final profile = await reader.profile(accountId);
      if (!isClosed && epoch == _epoch) {
        emit(AccountManagementState(profile: profile));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && epoch == _epoch) {
        emit(
          AccountManagementState(
            profile: state.profile,
            stale: state.profile != null,
            error: 'Не удалось обновить счёт. Проверьте сеть и повторите.',
          ),
        );
      }
    }
  }

  Future<bool> update(AccountPreferences preferences) async {
    if (state.saving || isClosed) return false;
    final epoch = ++_epoch;
    emit(AccountManagementState(profile: state.profile, saving: true));
    try {
      final profile = await reader.update(accountId, preferences);
      if (isClosed || epoch != _epoch) return false;
      emit(AccountManagementState(profile: profile));
      return true;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && epoch == _epoch) {
        emit(
          AccountManagementState(
            profile: state.profile,
            error: error is ApiFailure
                ? error.message
                : 'Настройка не сохранена. Повторите.',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    _epoch++;
    reader.close();
    return super.close();
  }
}
