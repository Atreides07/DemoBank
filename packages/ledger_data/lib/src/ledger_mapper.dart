import 'package:bank_core/bank_core.dart';

import 'json_fields.dart';

Account decodeAccount(Map<String, dynamic> json) => Account(
  id: json.string('id'),
  name: json.string('name'),
  balance: Money(json.integer('balanceMinor'), currency: _currency(json)),
  availableBalance: switch (json.optionalInteger('availableMinor')) {
    final minor? => Money(minor, currency: _currency(json)),
    null => null,
  },
  lastDigits: json.optionalString('lastDigits') ?? '',
  kind: json.optionalString('kind') ?? 'debit',
);

List<Account> decodeAccounts(Map<String, dynamic> json) =>
    List.unmodifiable(json.objects('accounts').map(decodeAccount));

LedgerEntry decodeLedgerEntry(Map<String, dynamic> json, {String? currency}) =>
    LedgerEntry(
      id: json.string('id'),
      title: json.string('title'),
      subtitle: json.optionalString('subtitle') ?? '',
      amount: Money(
        json.integer('amountMinor'),
        currency: _currency(json, inherited: currency),
      ),
      occurredAt: json.dateTime('occurredAt'),
      categoryId: json.string('categoryId'),
      merchantId: json.string('merchantId'),
      accountId: json.string('accountId'),
      kind: json.enumValue('kind', EntryKind.values),
      status: json.enumValue('status', EntryStatus.values),
    );

LedgerPage decodeLedgerPage(Map<String, dynamic> json) {
  final currency = _currency(json);
  return LedgerPage(
    items: json
        .objects('items')
        .map((row) => decodeLedgerEntry(row, currency: currency))
        .toList(growable: false),
    total: json.integer('total'),
    totalAmount: Money(json.integer('totalMinor'), currency: currency),
    revision: _revision(json),
    nextCursor: json.optionalString('nextCursor'),
    startIndex: json.optionalInteger('startIndex') ?? 0,
    startCursor: json.optionalString('startCursor'),
    prevCursor: json.optionalString('prevCursor'),
  );
}

AggregatePoint decodeAggregatePoint(
  Map<String, dynamic> json, {
  String? currency,
}) => AggregatePoint(
  id: json.string('id'),
  label: json.string('label'),
  amount: Money(
    json.integer('amountMinor'),
    currency: _currency(json, inherited: currency),
  ),
  count: json.integer('count'),
  from: json.optionalDateTime('from'),
  to: json.optionalDateTime('to'),
);

SpendingSummary decodeSpendingSummary(Map<String, dynamic> json) {
  final currency = _currency(json);
  List<AggregatePoint> points(String key) => json
      .objects(key)
      .map((row) => decodeAggregatePoint(row, currency: currency))
      .toList(growable: false);
  return SpendingSummary(
    total: Money(json.integer('totalMinor'), currency: currency),
    refunds: Money(json.integer('refundMinor'), currency: currency),
    previous: Money(json.integer('previousTotalMinor'), currency: currency),
    count: json.integer('count'),
    revision: _revision(json),
    categories: points('categories'),
    merchants: points('merchants'),
    timeline: points('timeline'),
    comparisonFrom: json.dateTime('comparisonFrom'),
    comparisonTo: json.dateTime('comparisonTo'),
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
  final resolved = own is String ? own : inherited;
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
