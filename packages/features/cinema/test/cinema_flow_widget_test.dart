import 'package:app_localizations/app_localizations.dart';
import 'package:checkout/checkout.dart';
import 'package:cinema/cinema.dart';
import 'package:design_system/design_system.dart';
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
  testWidgets('movie → session → available seat → payment → usable ticket', (
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
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: CinemaFeature(
            repository: ApiCinemaRepository(client),
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
    await tester.tap(find.text('Орбита света'));
    await _settle(tester);
    await _reveal(tester, find.byIcon(DsIcons.schedule).first);
    await _settle(tester);
    await tester.tap(find.byIcon(DsIcons.schedule).first);
    await _settle(tester);
    await _reveal(tester, find.text('Ряд 1 · место 1'));
    await _settle(tester);
    await tester.tap(find.text('Ряд 1 · место 1'));
    await _settle(tester);
    await _reveal(tester, find.text('Перейти к оплате'));
    await _settle(tester);
    await tester.tap(find.text('Перейти к оплате'));
    await _settle(tester);
    await _reveal(tester, find.text('Подтвердить оплату'));
    await _settle(tester);
    await tester.tap(find.text('Подтвердить оплату'));
    await _settle(tester);
    expect(find.text('Ваш билет'), findsOneWidget);
    expect(completed.single.ticket, contains('seat-1'));
    expect(completed.single.amount.minor, 65000);
    await _reveal(tester, find.text('Готово'));
    await _settle(tester);
    await tester.tap(find.text('Готово'));
    await _settle(tester);
    expect(find.text('Ряд 1 · место 1 · занято'), findsOneWidget);
    expect(find.text('Доступность мест изменилась'), findsNothing);
    expect(find.text('Ваш выбор'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });

  test(
    'competing purchase invalidates a quote and demands explicit reselection',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: SimulationAdapter(
          api: DemoApi(),
          scheduler: _InstantScheduler(),
        ),
      );
      final repository = ApiCinemaRepository(client);
      final controller = CinemaCubit(repository);
      await controller.loadMovies();
      await controller.selectMovie(controller.state.movies.first);
      await controller.selectSession(controller.state.sessions.first);
      controller.toggleSeat('seat-1', true);
      final intent = controller.intent('main');
      final gateway = ApiPaymentGateway(client);
      final original = await gateway.quote(intent);
      final competitor = await gateway.quote(intent);
      await gateway.submit(
        quoteId: competitor.id,
        idempotencyKey: 'other-user',
      );
      await expectLater(
        gateway.submit(quoteId: original.id, idempotencyKey: 'original-user'),
        throwsA(
          isA<PaymentFailure>().having(
            (failure) => failure.code,
            'code',
            PaymentFailureCode.seatConflict,
          ),
        ),
      );
      await controller.retry();
      expect(controller.state.selectedIds, isEmpty);
      expect(controller.state.seatsChanged, isTrue);
      expect(() => controller.intent('main'), throwsA(isA<PaymentFailure>()));
      await controller.close();
      client.close();
    },
  );
}
