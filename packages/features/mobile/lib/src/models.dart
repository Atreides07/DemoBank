import 'package:bank_core/bank_core.dart';
import 'package:payment_domain/payment_domain.dart';

final class MobileOperator {
  const MobileOperator({required this.id, required this.name});

  final String id;
  final String name;
}

final class OperatorLookup {
  OperatorLookup({required List<MobileOperator> operators, this.suggestedId})
    : operators = List.unmodifiable(operators);

  final List<MobileOperator> operators;
  final String? suggestedId;
}

abstract interface class MobileRepository {
  Future<OperatorLookup> operators(String phone);
}

String normalizeMobilePhone(String value) {
  if (!RegExp(r'^[+\d()\-\s]+$').hasMatch(value)) {
    throw const PaymentFailure(
      PaymentFailureCode.validation,
      'Введите российский номер телефона, например +7 916 123-45-67.',
    );
  }
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
  if (!RegExp(r'^7\d{10}$').hasMatch(digits)) {
    throw const PaymentFailure(
      PaymentFailureCode.validation,
      'Номер должен содержать 11 цифр и начинаться с +7 или 8.',
    );
  }
  return digits;
}

/// Decimal text is converted directly to integer minor units, never via double.
Money parseMobileAmount(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(normalized)) {
    throw const PaymentFailure(
      PaymentFailureCode.validation,
      'Введите сумму с точностью до копейки.',
    );
  }
  final parts = normalized.split('.');
  final minor =
      int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  if (minor < 10000 || minor > 1500000) {
    throw const PaymentFailure(
      PaymentFailureCode.validation,
      'Допустимая сумма: от 100 до 15 000 ₽.',
    );
  }
  return Money(minor);
}
