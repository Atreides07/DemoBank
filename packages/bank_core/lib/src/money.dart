/// Exact minor-unit arithmetic. Display formatting belongs to the
/// presentation layer, which knows the reader's language.
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

  /// Diagnostic representation, not for display.
  @override
  String toString() => 'Money($minor $currency)';
}
