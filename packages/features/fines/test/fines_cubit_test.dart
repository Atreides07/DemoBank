import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:fines/fines.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';

FineBill _bill(String id, {bool paid = false}) => FineBill(
  id: id,
  title: 'Штраф',
  description: 'Постановление',
  amount: const Money(50000),
  dueDate: DateTime.utc(2026, 11),
  paid: paid,
  version: '3',
);

final class _Repository implements FinesRepository {
  final responses = <String, Completer<List<FineBill>>>{};
  @override
  Future<List<FineBill>> search(String document) =>
      (responses[document] ??= Completer<List<FineBill>>()).future;
}

void main() {
  test(
    'out-of-order responses cannot replace the current document results',
    () async {
      final repository = _Repository();
      final controller = FinesCubit(repository);
      final older = controller.search('7712345678');
      final newer = controller.search('8812345678');
      repository.responses['8812345678']!.complete([_bill('new')]);
      await newer;
      repository.responses['7712345678']!.complete([_bill('old')]);
      await older;
      expect(controller.state.bills.single.id, 'new');
      await controller.close();
    },
  );

  test(
    'paid fine cannot be submitted; valid selection carries bill version',
    () async {
      final repository = _Repository();
      final controller = FinesCubit(repository);
      final request = controller.search('7712345678');
      repository.responses['7712345678']!.complete([
        _bill('one'),
        _bill('paid', paid: true),
      ]);
      await request;
      controller.select(controller.state.bills.first);
      final intent = controller.intent('source-account');
      expect(intent.referenceIds, ['one']);
      expect(intent.details['billVersions'], {'one': '3'});
      controller.select(controller.state.bills.last);
      expect(
        () => controller.intent('source-account'),
        throwsA(isA<PaymentFailure>()),
      );
      await controller.close();
    },
  );

  test('invalid document performs no network operation', () async {
    final repository = _Repository();
    final controller = FinesCubit(repository);
    await controller.search('123');
    expect(controller.state.phase, FinesPhase.failure);
    expect(repository.responses, isEmpty);
    await controller.close();
  });
}
