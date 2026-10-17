import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';
import 'package:utilities/utilities.dart';

UtilityBill _bill(String id, int amount, {bool paid = false}) => UtilityBill(
  id: id,
  title: 'Вода',
  provider: 'Ресурс',
  description: 'Октябрь',
  amount: Money(amount),
  dueDate: DateTime.utc(2026, 11),
  paid: paid,
  version: '2',
);

final class _Repository implements UtilitiesRepository {
  int requests = 0;
  @override
  Future<List<UtilityBill>> bills(String account) async {
    requests++;
    return [
      _bill('water', 10001),
      _bill('heat', 99999),
      _bill('paid', 12345, paid: true),
    ];
  }
}

void main() {
  test(
    'selection sums exact unpaid bills and cannot include stale paid bills',
    () async {
      final controller = UtilitiesCubit(_Repository());
      await controller.load('1234567890');
      controller.toggle('water', true);
      controller.toggle('heat', true);
      controller.toggle('paid', true);
      expect(controller.state.selectedTotal, const Money(110000));
      final intent = controller.intent('source');
      expect(intent.referenceIds, ['water', 'heat']);
      expect(intent.details['billVersions'], {'water': '2', 'heat': '2'});
      await controller.close();
    },
  );

  test('empty selection and invalid account cannot proceed', () async {
    final repository = _Repository();
    final controller = UtilitiesCubit(repository);
    await controller.load('abc');
    expect(repository.requests, 0);
    expect(() => controller.intent('source'), throwsA(isA<PaymentFailure>()));
    await controller.close();
  });
}
