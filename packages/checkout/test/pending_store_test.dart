import 'package:bank_core/bank_core.dart';
import 'package:checkout/checkout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';

void main() {
  test(
    'concurrent journal reservation and stale clear preserve the first key',
    () async {
      String? disk;
      final store = CallbackPendingPaymentStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final now = DateTime.utc(2026, 10, 16);
      final quote = PaymentQuote(
        id: 'q',
        amount: const Money(10000),
        fee: const Money(0),
        expiresAt: now.add(const Duration(minutes: 5)),
        recipient: 'ЖКХ',
        description: 'Счёт',
        intent: PaymentIntent(
          kind: PaymentKind.utilities,
          accountId: 'a',
          recipient: 'ЖКХ',
          referenceIds: ['u'],
        ),
      );
      final first = PendingPayment(
        idempotencyKey: 'first',
        quote: quote,
        preparedAt: now,
      );
      final second = PendingPayment(
        idempotencyKey: 'second',
        quote: quote,
        preparedAt: now,
      );
      final result = await Future.wait([
        store.reserve(first),
        store.reserve(second),
      ]);
      expect(result.map((entry) => entry.idempotencyKey), ['first', 'first']);
      await store.clear(expectedKey: 'unrelated-old-key');
      expect((await store.load())!.idempotencyKey, 'first');
      await store.clear(expectedKey: 'first');
      expect(await store.load(), isNull);
    },
  );

  test('durable journal roundtrips a cinema operation and exact fee', () async {
    String? disk;
    CallbackPendingPaymentStore open() => CallbackPendingPaymentStore(
      read: () async => disk,
      write: (value) async => disk = value,
    );
    final now = DateTime.utc(2026, 10, 16);
    final pending = PendingPayment(
      idempotencyKey: 'durable-key',
      preparedAt: now,
      quote: PaymentQuote(
        id: 'q1',
        amount: const Money(120099),
        fee: const Money(1000),
        expiresAt: now.add(const Duration(minutes: 5)),
        recipient: 'Кино',
        description: 'Два места',
        intent: PaymentIntent(
          kind: PaymentKind.cinema,
          accountId: 'a1',
          recipient: 'Кино',
          referenceIds: ['s1', 's2'],
          details: {'sessionId': 'session1', 'seatVersion': '2'},
        ),
      ),
    );
    await open().save(pending);
    final restored = (await open().load())!;
    expect(restored.idempotencyKey, pending.idempotencyKey);
    expect(restored.quote.total.minor, 121099);
    expect(restored.quote.intent.details, pending.quote.intent.details);
    expect(restored.quote.intent.referenceIds, ['s1', 's2']);
    await open().clear();
    expect(await open().load(), isNull);
  });

  test(
    'corrupt or unknown journal is surfaced and never silently discarded',
    () async {
      for (final content in ['not json', '{"version":99}']) {
        final store = CallbackPendingPaymentStore(
          read: () async => content,
          write: (_) async => fail('Corrupt journal must remain recoverable'),
        );
        await expectLater(
          store.load(),
          throwsA(
            isA<PaymentFailure>().having(
              (failure) => failure.code,
              'code',
              PaymentFailureCode.journalUnreadable,
            ),
          ),
        );
      }
    },
  );

  test(
    'an undecodable storage entry is unreadable; a failed read is retryable',
    () async {
      for (final (error, code) in [
        (
          const FormatException('corrupt row'),
          PaymentFailureCode.journalUnreadable,
        ),
        (StateError('database locked'), PaymentFailureCode.storage),
      ]) {
        final store = CallbackPendingPaymentStore(
          read: () async => throw error,
          write: (_) async => fail('A failed read must not write'),
        );
        await expectLater(
          store.load(),
          throwsA(
            isA<PaymentFailure>().having(
              (failure) => failure.code,
              'code',
              code,
            ),
          ),
        );
      }
    },
  );

  test(
    'discarding sets an unreadable entry aside and deletes a readable one',
    () async {
      String? disk = 'not json';
      var quarantined = 0;
      CallbackPendingPaymentStore open() => CallbackPendingPaymentStore(
        read: () async => disk,
        write: (value) async => disk = value,
        quarantine: () async {
          quarantined++;
          disk = null;
        },
      );
      await open().clear();
      expect(quarantined, 1, reason: 'Unreadable data is never deleted');
      expect(disk, isNull);

      final now = DateTime.utc(2026, 10, 16);
      await open().save(
        PendingPayment(
          idempotencyKey: 'readable',
          preparedAt: now,
          quote: PaymentQuote(
            id: 'q',
            amount: const Money(10000),
            fee: const Money(0),
            expiresAt: now.add(const Duration(minutes: 5)),
            recipient: 'ЖКХ',
            description: 'Счёт',
            intent: PaymentIntent(
              kind: PaymentKind.utilities,
              accountId: 'a',
              recipient: 'ЖКХ',
              referenceIds: ['u'],
            ),
          ),
        ),
      );
      await open().clear();
      expect(quarantined, 1);
      expect(disk, isNull);
    },
  );
}
