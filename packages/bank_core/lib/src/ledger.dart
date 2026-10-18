import 'money.dart';

final class Account {
  const Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.lastDigits,
    required this.kind,
    this.availableBalance,
  });
  final String id;
  final String name;
  final Money balance;
  final Money? availableBalance;
  Money get available => availableBalance ?? balance;
  final String lastDigits;
  final String kind;
}

enum EntryKind { expense, refund, income, transfer }

enum EntryStatus { posted, pending, cancelled }

final class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.occurredAt,
    required this.categoryId,
    required this.merchantId,
    required this.accountId,
    required this.kind,
    required this.status,
    this.cardId,
  });
  final String id;
  final String title;
  final String subtitle;
  final Money amount;
  final DateTime occurredAt;
  final String categoryId;
  final String merchantId;
  final String accountId;
  final EntryKind kind;
  final EntryStatus status;
  final String? cardId;
}

/// Half-open [from,to), interpreted in the reporting timezone (+03).
/// Account membership is a set; source ordering is retained for presentation.
final class LedgerFilter {
  LedgerFilter({
    this.from,
    this.to,
    this.category,
    this.merchant,
    this.cardId,
    List<String> accounts = const [],
    this.kind,
    this.revision,
    this.currency = 'RUB',
  }) : accounts = List.unmodifiable(accounts);
  final DateTime? from;
  final DateTime? to;
  final String? category;
  final String? merchant;
  final String? cardId;
  final List<String> accounts;
  final EntryKind? kind;
  final String? revision;
  final String currency;
  LedgerFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? category,
    String? merchant,
    String? cardId,
    List<String>? accounts,
    EntryKind? kind,
    String? revision,
    String? currency,
    bool clearCategory = false,
    bool clearMerchant = false,
  }) => LedgerFilter(
    from: from ?? this.from,
    to: to ?? this.to,
    category: clearCategory ? null : category ?? this.category,
    merchant: clearMerchant ? null : merchant ?? this.merchant,
    cardId: cardId ?? this.cardId,
    accounts: accounts ?? this.accounts,
    kind: kind ?? this.kind,
    revision: revision ?? this.revision,
    currency: currency ?? this.currency,
  );

  @override
  bool operator ==(Object other) =>
      other is LedgerFilter &&
      from?.microsecondsSinceEpoch == other.from?.microsecondsSinceEpoch &&
      to?.microsecondsSinceEpoch == other.to?.microsecondsSinceEpoch &&
      category == other.category &&
      merchant == other.merchant &&
      cardId == other.cardId &&
      kind == other.kind &&
      revision == other.revision &&
      currency == other.currency &&
      accounts.toSet().length == other.accounts.toSet().length &&
      accounts.toSet().containsAll(other.accounts);

  @override
  int get hashCode {
    final members = accounts.toSet().toList()..sort();
    return Object.hash(
      from?.microsecondsSinceEpoch,
      to?.microsecondsSinceEpoch,
      category,
      merchant,
      cardId,
      kind,
      revision,
      currency,
      Object.hashAll(members),
    );
  }
}

final class LedgerPage {
  LedgerPage({
    required List<LedgerEntry> items,
    required this.total,
    required this.totalAmount,
    required this.revision,
    this.nextCursor,
    this.startIndex = 0,
    this.startCursor,
    this.prevCursor,
  }) : items = List.unmodifiable(items);
  final List<LedgerEntry> items;
  final int total;
  final Money totalAmount;
  final String revision;
  final String? nextCursor;

  /// Global index in the revision and filter represented by this page.
  final int startIndex;
  final String? startCursor;
  final String? prevCursor;
}

final class AggregatePoint {
  const AggregatePoint({
    required this.id,
    required this.label,
    required this.amount,
    required this.count,
    this.from,
    this.to,
  });
  final String id;
  final String label;
  final Money amount;
  final int count;
  final DateTime? from;
  final DateTime? to;
}

final class SpendingSummary {
  SpendingSummary({
    required this.total,
    required this.refunds,
    required this.previous,
    required this.count,
    required this.revision,
    required List<AggregatePoint> categories,
    required List<AggregatePoint> merchants,
    required List<AggregatePoint> timeline,
    required this.comparisonFrom,
    required this.comparisonTo,
  }) : categories = List.unmodifiable(categories),
       merchants = List.unmodifiable(merchants),
       timeline = List.unmodifiable(timeline);
  final Money total;
  final Money refunds;
  final Money previous;
  final int count;
  final String revision;
  final List<AggregatePoint> categories;
  final List<AggregatePoint> merchants;
  final List<AggregatePoint> timeline;
  final DateTime comparisonFrom;
  final DateTime comparisonTo;
  double? get changePercent => previous.minor == 0
      ? null
      : (total.minor - previous.minor) * 100 / previous.minor;
}

abstract interface class AccountsReader {
  Future<List<Account>?> cachedAccounts();
  Future<List<Account>> accounts();
}

/// The server no longer serves the ledger revision a page was requested in.
/// Earlier pages are still valid to show; a fresh first page resolves the
/// current revision.
final class LedgerSnapshotExpired implements Exception {
  const LedgerSnapshotExpired();

  @override
  String toString() => 'LedgerSnapshotExpired';
}

abstract interface class HistoryReader {
  Future<LedgerPage?> cached(LedgerFilter filter, {String? cursor});
  Future<LedgerPage> page(
    LedgerFilter filter, {
    String? cursor,
    int limit = 30,
    int? startIndex,
  });

  /// Resolves a stable reading identity in a new snapshot. If it no longer
  /// matches, the server returns a clamped window near [fallbackIndex].
  Future<LedgerPage> around(
    LedgerFilter filter,
    String anchorId, {
    int fallbackIndex = 0,
  });
}

/// A history consumer owns its reads; changing filters must not cancel another
/// screen's page requests.
abstract interface class ScopedHistoryReader implements HistoryReader {
  ScopedHistoryReader createScope();
  void cancelPending();
}

abstract interface class AnalyticsReader {
  Future<SpendingSummary?> cached(LedgerFilter filter);
  Future<SpendingSummary> summary(LedgerFilter filter);
}

/// An independent consumer of shared analytics work. Cancelling one scope must
/// leave requests that other scopes still use alive.
abstract interface class ScopedAnalyticsReader implements AnalyticsReader {
  ScopedAnalyticsReader createScope();
  void cancelPending();
}
