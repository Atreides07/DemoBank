import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:local_storage/local_storage.dart';

/// Owned once by the application scope. Serial reservation protects two routes
/// from replacing each other's unresolved operation; storage is source-scoped.
final class CachedAccountOperationJournal implements AccountOperationJournal {
  CachedAccountOperationJournal(this.store);
  final CacheStore store;
  Future<void> _tail = Future.value();
  String _key(String id) => 'pending-account-operation:$id';
  @override
  Future<AccountOperation?> load(String accountId) async {
    final record = await store.read(_key(accountId));
    if (record == null) return null;
    final j = record.value;
    if (j['schema'] != 1 || j['accountId'] != accountId) {
      throw const FormatException('Account operation journal');
    }
    return AccountOperation(
      requestId: j['requestId'] as String,
      kind: AccountOperationKind.values.byName(j['kind'] as String),
      accountId: j['accountId'] as String,
      amount: Money(j['minor'] as int, currency: j['currency'] as String),
      destinationId: j['destinationId'] as String?,
    );
  }

  @override
  Future<AccountOperation> reserve(AccountOperation operation) =>
      _exclusive(() async {
        final pending = await load(operation.accountId);
        if (pending != null) return pending;
        await store.write(_key(operation.accountId), {
          'schema': 1,
          'requestId': operation.requestId,
          'kind': operation.kind.name,
          'accountId': operation.accountId,
          'minor': operation.amount.minor,
          'currency': operation.amount.currency,
          'destinationId': operation.destinationId,
        }, ttl: const Duration(days: 365));
        return operation;
      });
  @override
  Future<void> clear(AccountOperation operation) => _exclusive(() async {
    if ((await load(operation.accountId))?.requestId == operation.requestId) {
      await store.delete(_key(operation.accountId));
    }
  });
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
    }
  }
}
