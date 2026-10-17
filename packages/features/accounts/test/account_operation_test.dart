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
  @override
  Future<AccountOperationResult> execute(AccountOperation op) async {
    sent.add(op);
    if (reject) throw const AccountOperationRejected('Недостаточно средств');
    if (pending != null) return pending!.future;
    if (sent.length == 1) throw StateError('response lost after commit');
    return AccountOperationResult(
      id: 'one',
      requestId: op.requestId,
      amount: op.amount,
    );
  }

  @override
  Future<List<AccountRecipient>> recipients(String accountId) async => const [
    AccountRecipient(id: 'anna', name: 'Анна', bank: 'Демо', phone: '+7 (000)'),
  ];
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

void main() {
  test('decimal input never uses floating point or rounds user money', () {
    expect(AccountOperationCubit.parseMinor('1 234,05'), 123405);
    expect(AccountOperationCubit.parseMinor('0.01'), 1);
    for (final value in ['1.001', '-3', 'NaN', '1e3', '', '1,2,3']) {
      expect(AccountOperationCubit.parseMinor(value), isNull);
    }
  });
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
      first.review('125,37', 'savings');
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
      cubit.review('1', null);
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
      cubit.review('1', 'savings');
      expect(await cubit.submit(), isFalse);
      expect(cubit.state.step, AccountOperationStep.editing);
      expect(cubit.state.error, 'Недостаточно средств');
      expect(await journal.load('main'), isNull);
      await cubit.close();
    },
  );
  test(
    'concurrent reservations retain the first request and late clear cannot delete a new one',
    () async {
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
    },
  );
  test(
    'a corrupt durable journal blocks new submissions instead of replacing the key',
    () async {
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
      expect(cubit.state.error, isNotNull);
      cubit.review('1', null);
      expect(await cubit.submit(), isFalse);
      expect(reader.sent, isEmpty);
      await cubit.close();
    },
  );
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
    for (final pair in [
      ('0', 'savings'),
      ('1001', 'savings'),
      ('1.001', 'savings'),
      ('1', 'main'),
    ]) {
      cubit.review(pair.$1, pair.$2);
      expect(cubit.state.step, AccountOperationStep.editing);
      expect(cubit.state.error, isNotNull);
    }
    expect(reader.sent, isEmpty);
    await cubit.close();
  });
}
