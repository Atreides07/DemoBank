import 'package:checkout/checkout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:payment_domain/payment_domain.dart';

final _now = DateTime.utc(2026, 10, 16, 12);

final class _InstantScheduler implements SimulationScheduler {
  Duration _elapsed = Duration.zero;
  @override
  Duration get elapsed => _elapsed;
  @override
  Future<void> delay(
    Duration duration,
    SimulationCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    _elapsed += duration;
  }
}

final class _Clock implements PaymentClock {
  @override
  DateTime now() => _now;
}

final class _Keys implements IdempotencyKeyFactory {
  @override
  String next() => 'contract-stable-key';
}

PaymentIntent _intent() => PaymentIntent(
  kind: PaymentKind.utilities,
  accountId: 'main',
  recipient: 'ЖКХ',
  referenceIds: ['utility-001'],
  details: {
    'billVersions': {'utility-001': '1'},
  },
);

void main() {
  for (final profile in [NetworkProfile.normal, NetworkProfile.slow]) {
    test(
      'gateway ${profile.name}: exact quote, fee and idempotent receipt',
      () async {
        final api = DemoApi(now: () => _now);
        final adapter = SimulationAdapter(
          api: api,
          profile: profile,
          scheduler: _InstantScheduler(),
        );
        final client = ApiClient(
          baseUri: Uri.parse('https://demo.invalid/v1'),
          adapter: adapter,
        );
        final gateway = ApiPaymentGateway(client);
        final quote = await gateway.quote(_intent());
        expect(quote.fee.minor, 1000);
        expect(quote.total.minor, 685320);
        final first = await gateway.submit(
          quoteId: quote.id,
          idempotencyKey: 'same-key-idempotency',
        );
        final repeat = await gateway.submit(
          quoteId: quote.id,
          idempotencyKey: 'same-key-idempotency',
        );
        final recovered = await gateway.status('same-key-idempotency');
        expect(first.status, PaymentStatus.succeeded);
        expect(repeat.id, first.id);
        expect(recovered!.id, first.id);
        expect(repeat.receiptId, isNotEmpty);
        expect(
          adapter.events.where((event) => event.phase == 'chunk'),
          isNotEmpty,
        );
        client.close();
      },
    );
  }

  test(
    'lost real adapter response is reconciled without a second POST',
    () async {
      final api = DemoApi(now: () => _now);
      final adapter = SimulationAdapter(
        api: api,
        scheduler: _InstantScheduler(),
        faults: const [
          FaultRule(
            path: '/checkout/payments',
            method: 'POST',
            fault: SimulatedFault.lostResponse,
          ),
        ],
      );
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: adapter,
      );
      final controller = CheckoutCubit(
        gateway: ApiPaymentGateway(client),
        pendingStore: MemoryPendingPaymentStore(),
        clock: _Clock(),
        keyFactory: _Keys(),
      );
      await controller.begin(_intent());
      await controller.confirm();
      expect(controller.state.phase, CheckoutPhase.succeeded);
      expect(
        adapter.events.where(
          (event) =>
              event.method == 'POST' &&
              event.path == '/checkout/payments' &&
              event.phase == 'started',
        ),
        hasLength(1),
      );
      expect(
        adapter.events.any(
          (event) => event.path == '/checkout/payments/status',
        ),
        isTrue,
      );
      await controller.close();
      client.close();
    },
  );

  test(
    'pending server payment is recovered through a fresh controller',
    () async {
      final api = DemoApi(now: () => _now)..pendingNextPayment = true;
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: SimulationAdapter(api: api, scheduler: _InstantScheduler()),
      );
      final store = MemoryPendingPaymentStore();
      CheckoutCubit open() => CheckoutCubit(
        gateway: ApiPaymentGateway(client),
        pendingStore: store,
        clock: _Clock(),
        keyFactory: _Keys(),
      );
      final original = open();
      await original.begin(_intent());
      await original.confirm();
      expect(original.state.phase, CheckoutPhase.processing);
      await original.close();
      await api.settlePendingPayments();
      final restored = open();
      await restored.restore();
      expect(restored.state.phase, CheckoutPhase.succeeded);
      expect(await store.load(), isNull);
      await restored.close();
      client.close();
    },
  );

  test(
    'stale paid bill maps to typed failure before a second checkout',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: SimulationAdapter(
          api: DemoApi(now: () => _now),
          scheduler: _InstantScheduler(),
        ),
      );
      final gateway = ApiPaymentGateway(client);
      final quote = await gateway.quote(_intent());
      await gateway.submit(
        quoteId: quote.id,
        idempotencyKey: 'first-key-idempotency',
      );
      await expectLater(
        gateway.quote(_intent()),
        throwsA(
          isA<PaymentFailure>().having(
            (failure) => failure.code,
            'code',
            PaymentFailureCode.billStale,
          ),
        ),
      );
      client.close();
    },
  );
}
