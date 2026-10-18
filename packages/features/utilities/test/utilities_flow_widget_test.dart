import 'package:app_localizations/app_localizations.dart';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:payment_domain/payment_domain.dart';
import 'package:utilities/utilities.dart';

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

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await _settle(tester);
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: scrollable,
        maxScrolls: 40,
      );
    }
  }
  await tester.ensureVisible(finder);
  await _settle(tester);
}

void main() {
  testWidgets('account → selected bills → exact fee → receipt', (tester) async {
    final api = DemoApi();
    await tester.runAsync(api.warmUp);
    final client = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: SimulationAdapter(api: api, scheduler: _InstantScheduler()),
    );
    final completed = <PaymentRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: UtilitiesFeature(
            repository: ApiUtilitiesRepository(client),
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
    await tester.enterText(find.byType(TextField), '1234567890');
    await tester.tap(find.text('Получить начисления'));
    await _settle(tester);
    final first = find.byType(CheckboxListTile).first;
    await _reveal(tester, first);
    await _settle(tester);
    await tester.tap(first);
    await _settle(tester);
    await _reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), '2234567890');
    await _settle(tester);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Продолжить'), findsNothing);
    await tester.enterText(find.byType(TextField), '1234567890');
    await tester.tap(find.text('Получить начисления'));
    await _settle(tester);
    await _reveal(tester, first);
    await _settle(tester);
    await tester.tap(first);
    await _settle(tester);
    await _reveal(tester, find.text('Продолжить'));
    await _settle(tester);
    await tester.tap(find.text('Продолжить'));
    await _settle(tester);
    expect(find.text('Комиссия'), findsOneWidget);
    expect(find.text('10\u00a0₽'), findsOneWidget);
    await _reveal(tester, find.text('Подтвердить оплату'));
    await _settle(tester);
    await tester.tap(find.text('Подтвердить оплату'));
    await _settle(tester);
    expect(find.text('Оплата выполнена'), findsOneWidget);
    expect(completed.single.total.minor, 685320);
    expect(completed.single.fee.minor, 1000);
    await _reveal(tester, find.text('Готово'));
    await _settle(tester);
    await tester.tap(find.text('Готово'));
    await _settle(tester);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
