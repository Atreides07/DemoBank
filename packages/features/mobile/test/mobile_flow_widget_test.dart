import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:payment_domain/payment_domain.dart';

final class _InstantScheduler implements SimulationScheduler {
  @override
  Duration get elapsed => Duration.zero;
  @override
  Future<void> delay(
    Duration duration,
    SimulationCancellation cancellation,
  ) async => cancellation.throwIfCancelled();
}

Future<void> _settle(WidgetTester tester) async {
  for (var step = 0; step < 50; step++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone → detected operator → decimal amount → receipt', (
    tester,
  ) async {
    final api = DemoApi();
    await tester.runAsync(api.warmUp);
    final client = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: SimulationAdapter(api: api, scheduler: _InstantScheduler()),
    );
    final completed = <PaymentRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: MobileFeature(
            repository: ApiMobileRepository(client),
            accountId: 'main',
            onPaymentChanged: completed.add,
            checkout: CheckoutDependencies(
              gateway: ApiPaymentGateway(client),
              pendingStore: MemoryPendingPaymentStore(),
              clock: const SystemPaymentClock(),
              keyFactory: SecureIdempotencyKeyFactory(),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '+7 916 123-45-67');
    await tester.tap(find.text('Определить оператора'));
    await _settle(tester);
    expect(find.text('МТС'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField).last);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, '155,55');
    await tester.ensureVisible(find.text('Продолжить'));
    await _settle(tester);
    await tester.tap(find.text('Продолжить'));
    await _settle(tester);
    expect(find.text('МТС'), findsOneWidget);
    await tester.ensureVisible(find.text('Подтвердить оплату'));
    await _settle(tester);
    await tester.tap(find.text('Подтвердить оплату'));
    await _settle(tester);
    expect(find.text('Оплата выполнена'), findsOneWidget);
    expect(completed.single.amount.minor, 15555);
    expect(completed.single.fee.minor, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
