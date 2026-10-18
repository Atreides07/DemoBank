import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';

/// No payment may reach the gateway while the journal is unreadable.
final class _UnusedGateway implements PaymentGateway {
  @override
  Future<PaymentQuote> quote(PaymentIntent intent) =>
      throw StateError('Quote requested with an unreadable journal');

  @override
  Future<PaymentRecord> submit({
    required String quoteId,
    required String idempotencyKey,
  }) => throw StateError('Payment submitted with an unreadable journal');

  @override
  Future<PaymentRecord?> status(String idempotencyKey) =>
      throw StateError('Status requested with an unreadable journal');
}

final class _UnreadableStore implements PendingPaymentStore {
  bool unreadable = true;
  int discards = 0;

  @override
  Future<PendingPayment?> load() async {
    if (unreadable) {
      throw const PaymentFailure(
        PaymentFailureCode.journalUnreadable,
        'Сохранённый платёж повреждён',
      );
    }
    return null;
  }

  @override
  Future<void> save(PendingPayment payment) async {}

  @override
  Future<PendingPayment> reserve(PendingPayment candidate) async => candidate;

  @override
  Future<void> clear({String? expectedKey}) async {
    if (expectedKey == null) {
      discards++;
      unreadable = false;
    }
  }
}

final _now = DateTime.now().toUtc();

PaymentIntent _intent(String bill) => PaymentIntent(
  kind: PaymentKind.utilities,
  accountId: 'main',
  recipient: 'utilities',
  referenceIds: [bill],
);

PaymentQuote _quote(PaymentIntent intent) => PaymentQuote(
  id: 'quote-${intent.referenceIds.single}',
  intent: intent,
  amount: const Money(50000),
  fee: const Money(0),
  expiresAt: _now.add(const Duration(minutes: 10)),
  recipient: 'ЖКХ',
  description: 'Счёт ${intent.referenceIds.single}',
);

PaymentRecord _record(PendingPayment pending) => PaymentRecord(
  id: 'payment-${pending.idempotencyKey}',
  idempotencyKey: pending.idempotencyKey,
  quoteId: pending.quote.id,
  status: PaymentStatus.succeeded,
  amount: pending.quote.amount,
  fee: pending.quote.fee,
  createdAt: _now,
  description: pending.quote.description,
  receiptId: 'receipt-${pending.idempotencyKey}',
);

final class _ScriptedGateway implements PaymentGateway {
  Future<PaymentRecord> Function(String key)? onSubmit;
  final Map<String, PaymentRecord> records = {};
  int posts = 0;

  @override
  Future<PaymentQuote> quote(PaymentIntent intent) async => _quote(intent);

  @override
  Future<PaymentRecord> submit({
    required String quoteId,
    required String idempotencyKey,
  }) {
    posts++;
    return onSubmit!(idempotencyKey);
  }

  @override
  Future<PaymentRecord?> status(String idempotencyKey) async =>
      records[idempotencyKey];
}

final class _Calls {
  int back = 0;
  int finished = 0;
}

Future<void> _mount(
  WidgetTester tester, {
  required PaymentGateway gateway,
  required PendingPaymentStore store,
  required PaymentIntent intent,
  required _Calls calls,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DsAppTheme.light(),
      home: Scaffold(
        body: CheckoutView(
          dependencies: CheckoutDependencies(
            gateway: gateway,
            pendingStore: store,
            clock: const SystemPaymentClock(),
            keyFactory: SecureIdempotencyKeyFactory(),
          ),
          intent: intent,
          onBack: () => calls.back++,
          onFinished: () => calls.finished++,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unreadable journal is set aside only after confirmation', (
    tester,
  ) async {
    final store = _UnreadableStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: CheckoutView(
            dependencies: CheckoutDependencies(
              gateway: _UnusedGateway(),
              pendingStore: store,
              clock: const SystemPaymentClock(),
              keyFactory: SecureIdempotencyKeyFactory(),
            ),
            onFinished: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Оплата не выполнена'), findsOneWidget);

    await _tap(tester, 'Удалить повреждённую запись');
    expect(find.text('Удалить повреждённую запись?'), findsOneWidget);
    await _tap(tester, 'Отмена');
    expect(store.discards, 0, reason: 'Cancelling keeps the journal');
    expect(find.text('Удалить повреждённую запись?'), findsNothing);

    await _tap(tester, 'Удалить повреждённую запись');
    await _tap(tester, 'Удалить запись');
    expect(store.discards, 1);
    expect(find.text('Незавершённых платежей нет'), findsOneWidget);
  });

  testWidgets('a rejection that fresh terms cannot fix offers to change the '
      'details, and back returns to them', (tester) async {
    final gateway = _ScriptedGateway()
      ..onSubmit = (_) async =>
          throw const PaymentFailure(PaymentFailureCode.insufficientFunds);
    final calls = _Calls();
    await _mount(
      tester,
      gateway: gateway,
      store: MemoryPendingPaymentStore(),
      intent: _intent('bill-1'),
      calls: calls,
    );
    await _tap(tester, 'Подтвердить оплату');
    expect(find.text('Оплата не выполнена'), findsOneWidget);
    expect(find.text('Обновить условия'), findsNothing);
    await _tap(tester, 'Изменить данные');
    expect(calls.back, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls.back, 2, reason: 'nothing was charged, details are kept');
    expect(calls.finished, 0);
  });

  testWidgets('back is ignored while the payment is being sent', (
    tester,
  ) async {
    final response = Completer<PaymentRecord>();
    final store = MemoryPendingPaymentStore();
    final gateway = _ScriptedGateway()..onSubmit = (_) => response.future;
    final calls = _Calls();
    await _mount(
      tester,
      gateway: gateway,
      store: store,
      intent: _intent('bill-1'),
      calls: calls,
    );
    await tester.ensureVisible(find.text('Подтвердить оплату'));
    await tester.tap(find.text('Подтвердить оплату'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Получаем подтверждение'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls.back + calls.finished, 0);

    response.complete(_record((await store.load())!));
    await tester.pumpAndSettle();
    expect(find.text('Оплата выполнена'), findsOneWidget);
  });

  testWidgets('an earlier unfinished payment is named as such and the new one '
      'follows it', (tester) async {
    final store = MemoryPendingPaymentStore();
    final earlier = PendingPayment(
      idempotencyKey: 'earlier',
      quote: _quote(_intent('bill-old')),
      preparedAt: _now,
    );
    await store.save(earlier);
    final gateway = _ScriptedGateway()..records['earlier'] = _record(earlier);
    final calls = _Calls();
    await _mount(
      tester,
      gateway: gateway,
      store: store,
      intent: _intent('bill-new'),
      calls: calls,
    );
    expect(find.text('Сначала завершим предыдущий платёж'), findsOneWidget);
    expect(find.text('Счёт bill-old'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Оплата выполнена'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('Оплата выполнена'), findsOneWidget);
    expect(gateway.posts, 0, reason: 'the new payment was not sent');

    await _tap(tester, 'Перейти к новому платежу');
    expect(find.text('Сначала завершим предыдущий платёж'), findsNothing);
    expect(find.text('Счёт bill-new'), findsOneWidget);
    expect(find.text('Подтвердить оплату'), findsOneWidget);
    expect(calls.finished, 0);
  });
}
