import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile.dart';
import 'package:payment_domain/payment_domain.dart';

final class _Repository implements MobileRepository {
  Future<OperatorLookup> Function(String)? lookup;
  final requests = <String>[];
  @override
  Future<OperatorLookup> operators(String phone) async {
    requests.add(phone);
    return lookup == null
        ? OperatorLookup(
            operators: [const MobileOperator(id: 'm1', name: 'Мобильный')],
            suggestedId: 'm1',
          )
        : lookup!(phone);
  }
}

void main() {
  test('money parsing keeps every kopeck and rejects invalid limits', () {
    expect(parseMobileAmount('100,01'), const Money(10001));
    expect(parseMobileAmount('15000'), const Money(1500000));
    for (final amount in [
      '99.99',
      '15000.01',
      '-100',
      'NaN',
      '100.001',
      '1e3',
    ]) {
      expect(() => parseMobileAmount(amount), throwsA(isA<PaymentFailure>()));
    }
  });

  test('phone normalization preserves identity and rejects letters', () {
    expect(normalizeMobilePhone('8 (916) 123-45-67'), '79161234567');
    expect(normalizeMobilePhone('+7 916 123 45 67'), '79161234567');
    expect(
      () => normalizeMobilePhone('x79161234567'),
      throwsA(isA<PaymentFailure>()),
    );
  });

  test('outdated operator response cannot attach to a changed phone', () async {
    final response = Completer<OperatorLookup>();
    final repository = _Repository()..lookup = (_) => response.future;
    final controller = MobileCubit(repository);
    controller.changePhone('79161234567');
    final pending = controller.lookup();
    controller.changePhone('79261234567');
    response.complete(
      OperatorLookup(
        operators: [const MobileOperator(id: 'old', name: 'Старый')],
        suggestedId: 'old',
      ),
    );
    await pending;
    expect(controller.state.operators, isEmpty);
    expect(controller.state.canContinue, isFalse);
    await controller.close();
  });

  test(
    'selected operator and exact amount flow to checkout without bank imports',
    () async {
      final repository = _Repository();
      final controller = MobileCubit(repository);
      controller.changePhone('+7 916 123-45-67');
      await controller.lookup();
      controller.changeAmount('155,55');
      final intent = controller.intent('injected-account');
      expect(intent.amount, const Money(15555));
      expect(intent.accountId, 'injected-account');
      expect(intent.details['phone'], '79161234567');
      expect(repository.requests, ['79161234567']);
      controller.changeAmount('0');
      expect(controller.state.canContinue, isFalse);
      await controller.close();
    },
  );
}
