import 'package:intl/intl.dart';

/// Exact minor-unit arithmetic; conversion to a decimal is presentation only.
final class Money implements Comparable<Money> {
  const Money(this.minor, {this.currency = 'RUB'});
  final int minor;
  final String currency;

  Money operator +(Money other) {
    _checkCurrency(other);
    return Money(minor + other.minor, currency: currency);
  }

  Money operator -(Money other) {
    _checkCurrency(other);
    return Money(minor - other.minor, currency: currency);
  }

  void _checkCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Amounts in different currencies cannot be combined');
    }
  }

  String format({bool signed = false}) {
    final absolute = minor.abs();
    final whole = NumberFormat.decimalPattern('ru').format(absolute ~/ 100);
    final fraction = absolute % 100;
    final suffix = currency == 'RUB' ? '₽' : currency;
    final sign = minor < 0
        ? '−'
        : signed && minor > 0
        ? '+'
        : '';
    return '$sign$whole${fraction == 0 ? '' : ',${fraction.toString().padLeft(2, '0')}'} $suffix';
  }

  @override
  int compareTo(Money other) {
    _checkCurrency(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && minor == other.minor && currency == other.currency;
  @override
  int get hashCode => Object.hash(minor, currency);
  @override
  String toString() => format();
}
