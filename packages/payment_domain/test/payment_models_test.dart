import 'package:bank_core/bank_core.dart';
import 'package:payment_domain/payment_domain.dart';
import 'package:test/test.dart';

void main() {
  PaymentIntent intent() => PaymentIntent(
    kind: PaymentKind.fines,
    accountId: 'a1',
    recipient: 'ГИБДД',
    referenceIds: ['f1'],
  );

  test('amount and fee are summed exactly in minor units', () {
    final quote = PaymentQuote(
      id: 'q',
      intent: intent(),
      amount: const Money(19999),
      fee: const Money(101),
      expiresAt: DateTime.utc(2026),
      recipient: 'ГИБДД',
      description: 'Штраф',
    );
    expect(quote.total, const Money(20100));
  });
  test('mixed currency, negative fees and empty references are rejected', () {
    expect(
      () => PaymentQuote(
        id: 'q',
        intent: intent(),
        amount: const Money(10000),
        fee: const Money(1, currency: 'USD'),
        expiresAt: DateTime.utc(2026),
        recipient: 'ГИБДД',
        description: 'Штраф',
      ),
      throwsA(isA<PaymentFailure>()),
    );
    expect(
      () => PaymentIntent(
        kind: PaymentKind.fines,
        accountId: 'a1',
        recipient: 'ГИБДД',
        referenceIds: [],
      ),
      throwsA(isA<PaymentFailure>()),
    );
  });
  test(
    'intent snapshots collections rather than observing mutable UI input',
    () {
      final ids = ['f1'];
      final versions = <String, Object?>{'f1': '1'};
      final model = PaymentIntent(
        kind: PaymentKind.fines,
        accountId: 'a1',
        recipient: 'ГИБДД',
        referenceIds: ids,
        details: {'billVersions': versions},
      );
      ids.add('f2');
      versions['f1'] = 'stale-mutation';
      expect(model.referenceIds, ['f1']);
      expect(() => model.referenceIds.add('f3'), throwsUnsupportedError);
      expect(model.details['billVersions'], {'f1': '1'});
    },
  );
}
