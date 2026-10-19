import 'package:app_localizations/app_localizations.dart';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:fines/fines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('document → fine → confirmation → receipt → paid list', (
    tester,
  ) async {
    final api = DemoApi();
    await tester.runAsync(api.warmUp);
    final adapter = SimulationAdapter(
      api: api,
      profile: NetworkProfile.slow,
      scheduler: _InstantScheduler(),
    );
    final client = ApiClient(
      baseUri: Uri.parse('https://demo.invalid/v1'),
      adapter: adapter,
    );
    final changes = <PaymentRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DsAppTheme.light(brand: DsBrand.fines),
        home: Scaffold(
          body: FinesFeature(
            repository: ApiFinesRepository(client),
            accountId: 'main',
            checkout: CheckoutDependencies(
              gateway: ApiPaymentGateway(client),
              pendingStore: MemoryPendingPaymentStore(),
              clock: const SystemPaymentClock(),
              keyFactory: SecureIdempotencyKeyFactory(),
            ),
            onPaymentChanged: changes.add,
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '7712345678');
    await tester.tap(find.text('Найти штрафы'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '8812345678');
    await _settle(tester);
    expect(find.text('Превышение скорости'), findsNothing);
    await tester.enterText(find.byType(TextField), '7712345678');
    await tester.tap(find.text('Найти штрафы'));
    await _settle(tester);
    await _reveal(tester, find.text('Превышение скорости'));
    await _settle(tester);
    await tester.tap(find.text('Превышение скорости'));
    await _settle(tester);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '7712345678',
    );
    await tester.tap(find.text('Превышение скорости'));
    await _settle(tester);
    await _reveal(tester, find.text('Перейти к оплате'));
    await _settle(tester);
    await tester.tap(find.text('Перейти к оплате'));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Подробности штрафа'), findsOneWidget);
    expect(
      adapter.events.where(
        (event) => event.method == 'POST' && event.path == '/checkout/payments',
      ),
      isEmpty,
    );
    await _reveal(tester, find.text('Перейти к оплате'));
    await tester.tap(find.text('Перейти к оплате'));
    await _settle(tester);
    await _reveal(tester, find.text('Подтвердить оплату'));
    await _settle(tester);
    await tester.tap(find.text('Подтвердить оплату'));
    await tester.tap(find.text('Подтвердить оплату'));
    await _settle(tester);
    expect(find.text('Оплата выполнена'), findsOneWidget);
    expect(changes, hasLength(1));
    expect(changes.single.status, PaymentStatus.succeeded);
    expect(
      adapter.events.where(
        (event) =>
            event.method == 'POST' &&
            event.path == '/checkout/payments' &&
            event.phase == 'started',
      ),
      hasLength(1),
    );
    await _reveal(tester, find.text('Готово'));
    await _settle(tester);
    await tester.tap(find.text('Готово'));
    await _settle(tester);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });

  testWidgets(
    'empty search is explicit and screen is usable at large text scale',
    (tester) async {
      final api = DemoApi();
      await tester.runAsync(api.warmUp);
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: SimulationAdapter(api: api, scheduler: _InstantScheduler()),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DsAppTheme.dark(brand: DsBrand.fines),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: FinesFeature(
              repository: ApiFinesRepository(client),
              accountId: 'main',
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
      await tester.enterText(find.byType(TextField), '0000000000');
      await _reveal(tester, find.text('Найти штрафы'));
      await _settle(tester);
      await tester.tap(find.text('Найти штрафы'));
      await _settle(tester);
      expect(find.text('Штрафов нет'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    },
  );
}
