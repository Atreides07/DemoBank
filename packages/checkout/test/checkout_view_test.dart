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

Future<void> _tap(WidgetTester tester, String label) async {
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
}
