import 'dart:async';

import 'package:accounts/accounts.dart';
import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

const mainAccount = Account(
  id: 'main',
  name: 'Основной',
  balance: Money(100000),
  lastDigits: '0001',
  kind: 'debit',
);
const savings = Account(
  id: 'savings',
  name: 'Накопления',
  balance: Money(200000),
  lastDigits: '0002',
  kind: 'savings',
);

class _Reader implements AccountManagement {
  final sent = <AccountOperation>[];
  Completer<AccountOperationResult>? pending;
  bool reject = false;
  AccountOperationResult? result;
  bool recipientsOffline = false;
  int recipientRequests = 0;
  @override
  Future<AccountOperationResult> execute(AccountOperation op) async {
    sent.add(op);
    if (reject) throw const AccountOperationRejected('Недостаточно средств');
    if (pending != null) return pending!.future;
    if (result != null) return result!;
    if (sent.length == 1) throw StateError('response lost after commit');
    return AccountOperationResult(
      id: 'one',
      requestId: op.requestId,
      amount: op.amount,
    );
  }

  @override
  Future<List<AccountRecipient>> recipients(String accountId) async {
    recipientRequests++;
    if (recipientsOffline) throw StateError('server unavailable');
    return const [
      AccountRecipient(
        id: 'anna',
        name: 'Анна',
        bank: 'Демо',
        phone: '+7 (000)',
      ),
    ];
  }

  @override
  Future<AccountProfile?> cachedProfile(String id) async => null;
  @override
  Future<AccountProfile> profile(String id) => throw UnimplementedError();
  @override
  Future<AccountProfile> update(String id, AccountPreferences p) =>
      throw UnimplementedError();
  @override
  void close() {}
}

/// Contacts are unreachable until [online] is set.
class _OfflineContacts extends _Reader {
  bool online = false;
  @override
  Future<List<AccountRecipient>> recipients(String accountId) async {
    if (!online) throw StateError('offline');
    return super.recipients(accountId);
  }
}

void main() {
  for (final (index, result) in const [
    AccountOperationResult(id: 'one', requestId: 'wrong', amount: Money(100)),
    AccountOperationResult(id: 'one', requestId: 'key', amount: Money(999)),
    AccountOperationResult(
      id: 'one',
      requestId: 'key',
      amount: Money(100, currency: 'USD'),
    ),
    AccountOperationResult(id: '', requestId: 'key', amount: Money(100)),
  ].indexed) {
    test(
      'inconsistent operation result retains the original journal: $index',
      () async {
        final store = MemoryCacheStore();
        addTearDown(store.close);
        final journal = CachedAccountOperationJournal(store);
        final cubit = AccountOperationCubit(
          reader: _Reader()..result = result,
          account: mainAccount,
          kind: AccountOperationKind.topUp,
          accounts: const [mainAccount],
          nextId: () => 'key',
          journal: journal,
        );
        addTearDown(cubit.close);
        await cubit.restore();
        cubit.review(100, null);
        expect(await cubit.submit(), isFalse);
        expect(cubit.state.problem, AccountOperationProblem.resultUnknown);
        expect(cubit.canEdit, isFalse);
        expect((await journal.load('main'))!.requestId, 'key');
      },
    );
  }

  test(
    'recipient failure is retryable and never blocks a restored transfer',
    () async {
      final store = MemoryCacheStore();
      addTearDown(store.close);
      final journal = CachedAccountOperationJournal(store);
      final reader = _Reader()..recipientsOffline = true;
      final cubit = AccountOperationCubit(
        reader: reader,
        account: mainAccount,
        kind: AccountOperationKind.phoneTransfer,
        accounts: const [mainAccount],
        nextId: () => 'key',
        journal: journal,
      );
      addTearDown(cubit.close);
      await cubit.restore();
      expect(
        cubit.state.problem,
        AccountOperationProblem.recipientsUnavailable,
      );
      reader.recipientsOffline = false;
      await cubit.restore();
      expect(cubit.state.step, AccountOperationStep.editing);
      expect(cubit.recipients.single.id, 'anna');
      await journal.reserve(
        const AccountOperation(
          requestId: 'saved',
          accountId: 'main',
          kind: AccountOperationKind.phoneTransfer,
          destinationId: 'anna',
          amount: Money(100),
        ),
      );
      reader.recipientsOffline = true;
      final requests = reader.recipientRequests;
      await cubit.restore();
      expect(reader.recipientRequests, requests);
      expect(cubit.state.operation!.requestId, 'saved');
      expect(cubit.state.problem, AccountOperationProblem.restored);
      expect(cubit.canEdit, isFalse);
    },
  );

  test(
    'lost response restores same key after route and process restart',
    () async {
      final cache = MemoryCacheStore();
      addTearDown(cache.close);
      final reader = _Reader();
      final first = AccountOperationCubit(
        reader: reader,
        account: mainAccount,
        kind: AccountOperationKind.transfer,
        accounts: const [mainAccount, savings],
        nextId: () => 'stable-key',
        journal: CachedAccountOperationJournal(cache),
      );
      await first.restore();
      first.review(12537, 'savings');
      expect(first.state.step, AccountOperationStep.review);
      expect(await first.submit(), isFalse);
      expect(first.canEdit, isFalse);
      await first.close();
      final second = AccountOperationCubit(
        reader: reader,
        account: mainAccount,
        kind: AccountOperationKind.topUp,
        accounts: const [mainAccount, savings],
        nextId: () => 'must-not-be-used',
        journal: CachedAccountOperationJournal(cache),
      );
      await second.restore();
      expect(second.state.operation!.kind, AccountOperationKind.transfer);
      expect(second.state.operation!.requestId, 'stable-key');
      expect(second.state.operation!.amount, const Money(12537));
      expect(await second.submit(), isTrue);
      expect(reader.sent.map((o) => o.requestId), ['stable-key', 'stable-key']);
      expect(await CachedAccountOperationJournal(cache).load('main'), isNull);
      await second.close();
    },
  );
  test(
    'duplicate submit is ignored; journal clears only after success',
    () async {
      final cache = MemoryCacheStore();
      addTearDown(cache.close);
      final journal = CachedAccountOperationJournal(cache);
      final reader = _Reader()..pending = Completer();
      final cubit = AccountOperationCubit(
        reader: reader,
        account: mainAccount,
        kind: AccountOperationKind.topUp,
        accounts: const [mainAccount, savings],
        nextId: () => 'key',
        journal: journal,
      );
      await cubit.restore();
      cubit.review(100, null);
      final submitted = cubit.submit();
      expect(await cubit.submit(), isFalse);
      for (var n = 0; n < 5; n++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(reader.sent, hasLength(1));
      expect((await journal.load('main'))!.requestId, 'key');
      reader.pending!.complete(
        const AccountOperationResult(
          id: 'one',
          requestId: 'key',
          amount: Money(100),
        ),
      );
      expect(await submitted, isTrue);
      expect(await journal.load('main'), isNull);
      await cubit.close();
    },
  );
  test(
    'definitive rejection allows correction without a stuck journal',
    () async {
      final cache = MemoryCacheStore();
      addTearDown(cache.close);
      final journal = CachedAccountOperationJournal(cache);
      final cubit = AccountOperationCubit(
        reader: _Reader()..reject = true,
        account: mainAccount,
        kind: AccountOperationKind.transfer,
        accounts: const [mainAccount, savings],
        nextId: () => 'key',
        journal: journal,
      );
      await cubit.restore();
      cubit.review(100, 'savings');
      expect(await cubit.submit(), isFalse);
      expect(cubit.state.step, AccountOperationStep.editing);
      expect(cubit.state.problem, AccountOperationProblem.rejected);
      expect(cubit.state.serverMessage, 'Недостаточно средств');
      expect(await journal.load('main'), isNull);
      await cubit.close();
    },
  );
  test('concurrent reservations retain the first request and late clear cannot delete a new one', () async {
    final cache = MemoryCacheStore();
    addTearDown(cache.close);
    final journal = CachedAccountOperationJournal(cache);
    const a = AccountOperation(
      requestId: 'a',
      kind: AccountOperationKind.topUp,
      accountId: 'main',
      amount: Money(1),
    );
    const b = AccountOperation(
      requestId: 'b',
      kind: AccountOperationKind.topUp,
      accountId: 'main',
      amount: Money(2),
    );
    final reserved = await Future.wait([
      journal.reserve(a),
      journal.reserve(b),
    ]);
    expect(reserved.map((o) => o.requestId), ['a', 'a']);
    await journal.clear(a);
    await journal.reserve(b);
    await journal.clear(a);
    expect((await journal.load('main'))!.requestId, 'b');
  });
  test('a corrupt durable journal blocks new submissions instead of replacing the key', () async {
    final cache = MemoryCacheStore();
    addTearDown(cache.close);
    await cache.write('pending-account-operation:main', {
      'schema': 999,
      'accountId': 'main',
    });
    final reader = _Reader();
    final cubit = AccountOperationCubit(
      reader: reader,
      account: mainAccount,
      kind: AccountOperationKind.topUp,
      accounts: const [mainAccount, savings],
      nextId: () => 'new',
      journal: CachedAccountOperationJournal(cache),
    );
    await cubit.restore();
    expect(cubit.state.step, AccountOperationStep.restoring);
    expect(cubit.state.problem, AccountOperationProblem.journalUnreadable);
    cubit.review(100, null);
    expect(await cubit.submit(), isFalse);
    expect(reader.sent, isEmpty);
    await cubit.close();
  });
  test('invalid input and recipient do not reach the repository', () async {
    final cache = MemoryCacheStore();
    addTearDown(cache.close);
    final reader = _Reader();
    final cubit = AccountOperationCubit(
      reader: reader,
      account: mainAccount,
      kind: AccountOperationKind.transfer,
      accounts: const [mainAccount, savings],
      nextId: () => 'key',
      journal: CachedAccountOperationJournal(cache),
    );
    await cubit.restore();
    for (final (minor, destination, problem) in [
      (0, 'savings', AccountOperationProblem.invalidAmount),
      (null, 'savings', AccountOperationProblem.invalidAmount),
      (100100, 'savings', AccountOperationProblem.insufficientFunds),
      (100, 'main', AccountOperationProblem.invalidDestination),
    ]) {
      cubit.review(minor, destination);
      expect(cubit.state.step, AccountOperationStep.editing);
      expect(cubit.state.problem, problem);
    }
    expect(reader.sent, isEmpty);
    await cubit.close();
  });

  test('unreachable contacts are not reported as a damaged journal', () async {
    final cache = MemoryCacheStore();
    addTearDown(cache.close);
    final reader = _OfflineContacts();
    final cubit = AccountOperationCubit(
      reader: reader,
      account: mainAccount,
      kind: AccountOperationKind.phoneTransfer,
      accounts: const [mainAccount, savings],
      nextId: () => 'key',
      journal: CachedAccountOperationJournal(cache),
    );
    await cubit.restore();
    expect(cubit.state.step, AccountOperationStep.editing);
    expect(cubit.state.problem, AccountOperationProblem.recipientsUnavailable);
    expect(cubit.recipients, isEmpty);

    reader.online = true;
    await cubit.retryRecipients();
    expect(cubit.state.step, AccountOperationStep.editing);
    expect(cubit.state.problem, isNull);
    expect(cubit.recipients.single.id, 'anna');
    cubit.review(100, 'anna');
    expect(cubit.state.step, AccountOperationStep.review);
    await cubit.close();
  });

  test(
    'a saved request is restored even when contacts are unreachable',
    () async {
      final cache = MemoryCacheStore();
      addTearDown(cache.close);
      final journal = CachedAccountOperationJournal(cache);
      await journal.reserve(
        const AccountOperation(
          requestId: 'saved',
          kind: AccountOperationKind.phoneTransfer,
          accountId: 'main',
          amount: Money(500),
          destinationId: 'anna',
        ),
      );
      final cubit = AccountOperationCubit(
        reader: _OfflineContacts(),
        account: mainAccount,
        kind: AccountOperationKind.phoneTransfer,
        accounts: const [mainAccount, savings],
        nextId: () => 'new',
        journal: journal,
      );
      await cubit.restore();
      expect(cubit.state.step, AccountOperationStep.review);
      expect(cubit.state.operation?.requestId, 'saved');
      expect(cubit.state.problem, AccountOperationProblem.restored);
      await cubit.close();
    },
  );
}
