import 'package:bank_core/bank_core.dart';

Account decodeAccount(Map<String, dynamic> json) => Account(
  id: json['id'] as String,
  name: json['name'] as String,
  balance: Money(json['balanceMinor'] as int, currency: _currency(json)),
  availableBalance: json['availableMinor'] == null
      ? null
      : Money(json['availableMinor'] as int, currency: _currency(json)),
  lastDigits: json['lastDigits'] as String? ?? '',
  kind: json['kind'] as String? ?? 'debit',
);

List<Account> decodeAccounts(Map<String, dynamic> json) =>
    List.unmodifiable(_rows(json, 'accounts').map(decodeAccount));

LedgerEntry decodeLedgerEntry(Map<String, dynamic> json, {String? currency}) =>
    LedgerEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      amount: Money(
        json['amountMinor'] as int,
        currency: _currency(json, inherited: currency),
      ),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      categoryId: json['categoryId'] as String,
      merchantId: json['merchantId'] as String,
      accountId: json['accountId'] as String,
      kind: EntryKind.values.byName(json['kind'] as String),
      status: EntryStatus.values.byName(json['status'] as String),
    );

LedgerPage decodeLedgerPage(Map<String, dynamic> json) {
  final currency = _currency(json);
  return LedgerPage(
    items: _rows(json, 'items')
        .map((row) => decodeLedgerEntry(row, currency: currency))
        .toList(growable: false),
    total: json['total'] as int,
    totalAmount: Money(json['totalMinor'] as int, currency: currency),
    revision: _revision(json),
    nextCursor: json['nextCursor'] as String?,
    startIndex: json['startIndex'] as int? ?? 0,
    startCursor: json['startCursor'] as String?,
    prevCursor: json['prevCursor'] as String?,
  );
}

AggregatePoint decodeAggregatePoint(
  Map<String, dynamic> json, {
  String? currency,
}) => AggregatePoint(
  id: json['id'] as String,
  label: json['label'] as String,
  amount: Money(
    json['amountMinor'] as int,
    currency: _currency(json, inherited: currency),
  ),
  count: json['count'] as int,
  from: json['from'] == null ? null : DateTime.parse(json['from'] as String),
  to: json['to'] == null ? null : DateTime.parse(json['to'] as String),
);

SpendingSummary decodeSpendingSummary(Map<String, dynamic> json) {
  final currency = _currency(json);
  List<AggregatePoint> points(String key) => _rows(json, key)
      .map((row) => decodeAggregatePoint(row, currency: currency))
      .toList(growable: false);
  return SpendingSummary(
    total: Money(json['totalMinor'] as int, currency: currency),
    refunds: Money(json['refundMinor'] as int, currency: currency),
    previous: Money(json['previousTotalMinor'] as int, currency: currency),
    count: json['count'] as int,
    revision: _revision(json),
    categories: points('categories'),
    merchants: points('merchants'),
    timeline: points('timeline'),
    comparisonFrom: DateTime.parse(json['comparisonFrom'] as String),
    comparisonTo: DateTime.parse(json['comparisonTo'] as String),
  );
}

/// Transport query and cache representation are explicitly outside bank_core.
/// Values remain unescaped here; the HTTP client performs URL serialization.
extension LedgerFilterEncoding on LedgerFilter {
  Map<String, dynamic> toQuery() {
    final members = accounts.toSet().toList()..sort();
    return {
      'currency': currency,
      if (from != null) 'from': from!.toUtc().toIso8601String(),
      if (to != null) 'to': to!.toUtc().toIso8601String(),
      if (category != null) 'category': category,
      if (merchant != null) 'merchant': merchant,
      if (members.isNotEmpty) 'accounts': members.join(','),
      if (kind != null) 'kind': kind!.name,
      if (revision != null) 'revision': revision,
    };
  }

  /// Canonical field/account ordering and URL escaping prevent delimiter
  /// collisions between filters. UTC normalization matches value equality.
  String get cacheKey {
    final values = toQuery();
    final keys = values.keys.toList()..sort();
    return Uri(
      queryParameters: {for (final key in keys) key: values[key].toString()},
    ).query;
  }
}

String _currency(Map<String, dynamic> json, {String? inherited}) {
  final own = json['currency'];
  if (own != null && (own is! String || own.isEmpty)) {
    throw const FormatException('Invalid ledger currency');
  }
  final resolved = own as String? ?? inherited;
  if (resolved == null || resolved.isEmpty) {
    throw const FormatException('Ledger currency is required');
  }
  if (inherited != null && resolved != inherited) {
    throw const FormatException('Mixed currencies in a single ledger response');
  }
  return resolved;
}

String _revision(Map<String, dynamic> json) {
  final value = json['revision'];
  if (value is! String && value is! int) {
    throw const FormatException('Ledger revision is required');
  }
  return value.toString();
}

Iterable<Map<String, dynamic>> _rows(Map<String, dynamic> json, String key) =>
    (json[key] as List<Object?>).map(
      (row) => Map<String, dynamic>.from(row! as Map),
    );
