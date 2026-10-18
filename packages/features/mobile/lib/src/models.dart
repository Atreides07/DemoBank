import 'package:bank_core/bank_core.dart';

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

/// Why a phone number or amount cannot be used. The screen chooses the words.
enum MobileInputError {
  phoneCharacters,
  phoneLength,
  amountFormat,
  amountRange,
}

final class MobileInputException implements Exception {
  const MobileInputException(this.error);

  final MobileInputError error;

  @override
  String toString() => 'MobileInputException(${error.name})';
}

/// Top-up limits of the mobile operators.
const mobileMinimumAmount = Money(10000);
const mobileMaximumAmount = Money(1500000);

/// Russian numbers only: 11 digits starting with 7, a leading 8 is accepted.
String normalizeMobilePhone(String value) {
  if (!RegExp(r'^[+\d()\-\s]+$').hasMatch(value)) {
    throw const MobileInputException(MobileInputError.phoneCharacters);
  }
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
  if (!RegExp(r'^7\d{10}$').hasMatch(digits)) {
    throw const MobileInputException(MobileInputError.phoneLength);
  }
  return digits;
}

/// Checks an amount already parsed into exact minor units by the screen;
/// `null` means the text was not an amount.
Money checkMobileAmount(int? minor) {
  if (minor == null) {
    throw const MobileInputException(MobileInputError.amountFormat);
  }
  if (minor < mobileMinimumAmount.minor || minor > mobileMaximumAmount.minor) {
    throw const MobileInputException(MobileInputError.amountRange);
  }
  return Money(minor);
}
