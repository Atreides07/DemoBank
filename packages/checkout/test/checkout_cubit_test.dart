import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:checkout/checkout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';

final _now = DateTime.utc(2026, 10, 16, 12);

PaymentIntent _intent() => PaymentIntent(
  kind: PaymentKind.utilities,
  accountId: 'account-1',
  recipient: 'ЖКХ',
  referenceIds: ['bill-1'],
);

PaymentQuote _quote({DateTime? expiresAt}) => PaymentQuote(
  id: 'quote-1',
  intent: _intent(),
  amount: const Money(890050),
  fee: const Money(1000),
  expiresAt: expiresAt ?? _now.add(const Duration(minutes: 5)),
  recipient: 'ЖКХ',
  description: 'Счёт за сентябрь',
);

PaymentRecord _record(
  String key, {
  PaymentStatus status = PaymentStatus.succeeded,
  int amountMinor = 890050,
}) => PaymentRecord(
  id: 'payment-1',
  idempotencyKey: key,
  quoteId: 'quote-1',
  status: status,
  amount: Money(amountMinor),
  fee: const Money(1000),
  createdAt: _now,
  description: 'Счёт за сентябрь',
  receiptId: 'receipt-1',
);

final class _Clock implements PaymentClock {
  @override
  DateTime now() => _now;
}

final class _Keys implements IdempotencyKeyFactory {
  int generated = 0;
  @override
  String next() => 'stable-${++generated}';
}

final class _Gateway implements PaymentGateway {
  PaymentQuote quoteValue = _quote();
  PaymentRecord? serverRecord;
  int posts = 0;
  int statusChecks = 0;
  final List<String> keys = [];
  Future<PaymentRecord> Function(String)? send;

  @override
  Future<PaymentQuote> quote(PaymentIntent intent) async => quoteValue;

  @override
  Future<PaymentRecord> submit({
    required String quoteId,
    required String idempotencyKey,
  }) async {
    posts++;
    keys.add(idempotencyKey);
    return send == null
        ? serverRecord ??= _record(idempotencyKey)
        : send!(idempotencyKey);
  }

  @override
  Future<PaymentRecord?> status(String idempotencyKey) async {
    statusChecks++;
    return serverRecord;
  }
}

final class _BrokenStore implements PendingPaymentStore {
  @override
  Future<PendingPayment?> load() async => null;
  @override
  Future<void> save(PendingPayment payment) async =>
      throw StateError('disk full');
  @override
  Future<void> clear({String? expectedKey}) async {}
  @override
  Future<PendingPayment> reserve(PendingPayment candidate) async =>
      throw StateError('disk full');
}

void main() {
  late _Gateway gateway;
  late MemoryPendingPaymentStore store;
  late _Keys keys;
  late CheckoutCubit controller;

  setUp(() {
    gateway = _Gateway();
    store = MemoryPendingPaymentStore();
    keys = _Keys();
    controller = CheckoutCubit(
      gateway: gateway,
      pendingStore: store,
      clock: _Clock(),
      keyFactory: keys,
    );
  });
  tearDown(() => controller.close());

  test('double confirmation sends once and persists before sending', () async {
    final response = Completer<PaymentRecord>();
    gateway.send = (key) async {
      expect((await store.load())!.idempotencyKey, key);
      return response.future;
    };
    await controller.begin(_intent());
    final first = controller.confirm();
    await controller.confirm();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.posts, 1);
    expect(keys.generated, 1);
    response.complete(_record('stable-1'));
    await first;
    expect(controller.state.phase, CheckoutPhase.succeeded);
    expect(await store.load(), isNull);
  });

  test('timeout after acceptance queries status and does not repost', () async {
    gateway.send = (key) async {
      gateway.serverRecord = _record(key);
      throw const PaymentFailure(PaymentFailureCode.timeout, 'lost response');
    };
    await controller.begin(_intent());
    await controller.confirm();
    expect(controller.state.phase, CheckoutPhase.succeeded);
    expect(gateway.posts, 1);
    expect(gateway.statusChecks, 1);
    expect(await store.load(), isNull);
  });

  test(
    'unknown outcome survives controller restart with same operation',
    () async {
      gateway.send = (_) async => throw const PaymentFailure(
        PaymentFailureCode.network,
        'connection lost',
      );
      await controller.begin(_intent());
      await controller.confirm();
      expect(controller.state.phase, CheckoutPhase.uncertain);
      final key = (await store.load())!.idempotencyKey;
      gateway.serverRecord = _record(key);
      await controller.close();
      controller = CheckoutCubit(
        gateway: gateway,
        pendingStore: store,
        clock: _Clock(),
        keyFactory: keys,
      );
      await controller.restore();
      expect(controller.state.phase, CheckoutPhase.succeeded);
      expect(gateway.posts, 1);
      expect(keys.generated, 1);
    },
  );

  test(
    'explicit retry reuses stored key; checking alone never reposts',
    () async {
      gateway.send = (_) async => throw const PaymentFailure(
        PaymentFailureCode.timeout,
        'connection lost',
      );
      await controller.begin(_intent());
      await controller.confirm();
      await controller.checkStatus();
      expect(gateway.posts, 1);
      gateway.send = (key) async => gateway.serverRecord = _record(key);
      await controller.retrySamePayment();
      expect(gateway.keys, ['stable-1', 'stable-1']);
      expect(keys.generated, 1);
      expect(controller.state.phase, CheckoutPhase.succeeded);
    },
  );

  test('pending server response is not represented as completed', () async {
    gateway.send = (key) async =>
        gateway.serverRecord = _record(key, status: PaymentStatus.pending);
    await controller.begin(_intent());
    await controller.confirm();
    expect(controller.state.phase, CheckoutPhase.processing);
    expect(await store.load(), isNotNull);
    gateway.serverRecord = _record('stable-1');
    await controller.checkStatus();
    expect(controller.state.phase, CheckoutPhase.succeeded);
  });

  test('expired quote is rejected locally without a POST', () async {
    gateway.quoteValue = _quote(expiresAt: _now);
    await controller.begin(_intent());
    await controller.confirm();
    expect(gateway.posts, 0);
    expect(controller.state.failure!.code, PaymentFailureCode.quoteExpired);
  });

  test(
    'durability failure blocks submission before any money mutation',
    () async {
      await controller.close();
      controller = CheckoutCubit(
        gateway: gateway,
        pendingStore: _BrokenStore(),
        clock: _Clock(),
        keyFactory: keys,
      );
      await controller.begin(_intent());
      await controller.confirm();
      expect(gateway.posts, 0);
      expect(controller.state.failure!.code, PaymentFailureCode.storage);
    },
  );

  test(
    'confirmed seat conflict clears journal and requests reselection',
    () async {
      gateway.send = (_) async => throw const PaymentFailure(
        PaymentFailureCode.seatConflict,
        'Место уже занято',
      );
      await controller.begin(_intent());
      await controller.confirm();
      expect(controller.state.phase, CheckoutPhase.failed);
      expect(controller.state.failure!.code, PaymentFailureCode.seatConflict);
      expect(await store.load(), isNull);
      expect(gateway.statusChecks, 0);
    },
  );

  test('inconsistent server record cannot create a false success', () async {
    gateway.send = (key) async => _record(key, amountMinor: 1);
    await controller.begin(_intent());
    await controller.confirm();
    expect(controller.state.phase, CheckoutPhase.uncertain);
    expect(await store.load(), isNotNull);
  });

  test(
    'existing operation is recovered before quoting a different service',
    () async {
      await store.save(
        PendingPayment(
          idempotencyKey: 'existing',
          quote: _quote(),
          preparedAt: _now,
        ),
      );
      gateway.serverRecord = _record('existing', status: PaymentStatus.pending);
      await controller.begin(
        PaymentIntent(
          kind: PaymentKind.fines,
          accountId: 'account-1',
          recipient: 'ГИБДД',
          referenceIds: ['fine-2'],
        ),
      );
      expect(controller.state.quote!.intent.kind, PaymentKind.utilities);
      expect(controller.state.phase, CheckoutPhase.processing);
      expect(gateway.posts, 0);
      expect(keys.generated, 0);
    },
  );

  test(
    'two checkout scopes cannot overwrite an unresolved operation',
    () async {
      final response = Completer<PaymentRecord>();
      gateway.send = (_) => response.future;
      final second = CheckoutCubit(
        gateway: gateway,
        pendingStore: store,
        clock: _Clock(),
        keyFactory: keys,
      );
      await controller.begin(_intent());
      await second.begin(_intent());
      final firstSubmission = controller.confirm();
      await second.confirm();
      expect(gateway.posts, 1);
      expect(second.state.phase, CheckoutPhase.uncertain);
      expect((await store.load())!.idempotencyKey, 'stable-1');
      response.complete(_record('stable-1'));
      await firstSubmission;
      await second.close();
    },
  );
}
