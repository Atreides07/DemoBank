import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile.dart';

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
  test('amount limits keep every kopeck and reject the rest', () {
    expect(checkMobileAmount(10001), const Money(10001));
    expect(checkMobileAmount(1500000), const Money(1500000));
    for (final (minor, error) in [
      (9999, MobileInputError.amountRange),
      (1500001, MobileInputError.amountRange),
      (-10000, MobileInputError.amountRange),
      (null, MobileInputError.amountFormat),
    ]) {
      expect(
        () => checkMobileAmount(minor),
        throwsA(
          isA<MobileInputException>().having((e) => e.error, 'error', error),
        ),
      );
    }
  });

  test('phone normalization preserves identity and rejects letters', () {
    expect(normalizeMobilePhone('8 (916) 123-45-67'), '79161234567');
    expect(normalizeMobilePhone('+7 916 123 45 67'), '79161234567');
    expect(
      () => normalizeMobilePhone('x79161234567'),
      throwsA(
        isA<MobileInputException>().having(
          (e) => e.error,
          'error',
          MobileInputError.phoneCharacters,
        ),
      ),
    );
    expect(
      () => normalizeMobilePhone('+7 916 123'),
      throwsA(
        isA<MobileInputException>().having(
          (e) => e.error,
          'error',
          MobileInputError.phoneLength,
        ),
      ),
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
      controller.changeAmount(15555);
      final intent = controller.intent('injected-account');
      expect(intent.amount, const Money(15555));
      expect(intent.accountId, 'injected-account');
      expect(intent.recipient, 'm1');
      expect(intent.details['phone'], '79161234567');
      expect(repository.requests, ['79161234567']);
      controller.changeAmount(0);
      expect(controller.state.canContinue, isFalse);
      expect(controller.state.amountError, MobileInputError.amountRange);
      controller.changeAmount(null);
      expect(controller.state.amountError, MobileInputError.amountFormat);
      await controller.close();
    },
  );
}
