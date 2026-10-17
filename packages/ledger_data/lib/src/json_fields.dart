/// Typed reads from untrusted JSON (API responses and cached copies of them).
///
/// Every contract violation is a [FormatException] naming the field, never a
/// `TypeError` from a cast, so callers can tell malformed data from a defect.
/// Values are not echoed into the exception: they may contain personal data.
extension JsonFields on Map<String, dynamic> {
  String string(String key) => _field<String>(key);

  String? optionalString(String key) => _field<String?>(key);

  int integer(String key) => _field<int>(key);

  int? optionalInteger(String key) => _field<int?>(key);

  bool boolean(String key) => _field<bool>(key);

  DateTime dateTime(String key) =>
      DateTime.tryParse(string(key)) ??
      (throw FormatException('Field "$key" must be an ISO-8601 timestamp'));

  DateTime? optionalDateTime(String key) =>
      this[key] == null ? null : dateTime(key);

  /// An unknown name is a contract violation, not an `ArgumentError`.
  T enumValue<T extends Enum>(String key, List<T> values) {
    final name = string(key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Field "$key" has an unsupported value');
  }

  Iterable<Map<String, dynamic>> objects(String key) =>
      _field<List<Object?>>(key).map(
        (row) => row is Map<String, dynamic>
            ? row
            : row is Map
            ? Map<String, dynamic>.from(row)
            : throw FormatException('Field "$key" must contain objects'),
      );

  Map<String, String> stringMap(String key) {
    final result = <String, String>{};
    for (final entry in _field<Map<Object?, Object?>>(key).entries) {
      final (name, text) = (entry.key, entry.value);
      if (name is! String || text is! String) {
        throw FormatException('Field "$key" must map strings to strings');
      }
      result[name] = text;
    }
    return result;
  }

  T _field<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw FormatException('Field "$key" must be $T');
  }
}
