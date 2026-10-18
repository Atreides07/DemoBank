import 'money.dart';

final class AccountCard {
  const AccountCard({
    required this.id,
    required this.lastDigits,
    this.frozen = false,
    this.monthlyLimit,
  });
  final String id;
  final String lastDigits;
  final bool frozen;
  final Money? monthlyLimit;
}

final class AccountLimit {
  const AccountLimit({
    required this.id,
    required this.title,
    required this.limit,
    required this.remaining,
  });
  final String id;
  final String title;
  final Money limit;
  final Money remaining;
}

final class AccountProfile {
  AccountProfile({
    required this.id,
    required this.name,
    required this.cashback,
    required this.cashbackDate,
    required this.contract,
    required Map<String, String> requisites,
    required List<AccountCard> cards,
    required List<AccountLimit> limits,
    this.autoTopUp = false,
    this.roundUp = false,
    this.charity = false,
    this.cashbackDestination = 'main',
    this.linkedServicesEnabled = true,
  }) : cards = List.unmodifiable(cards),
       limits = List.unmodifiable(limits),
       requisites = Map.unmodifiable(requisites);
  final String id;
  final String name;
  final Money cashback;
  final DateTime cashbackDate;
  final String contract;
  final Map<String, String> requisites;
  final List<AccountCard> cards;
  final List<AccountLimit> limits;
  final bool autoTopUp;
  final bool roundUp;
  final bool charity;
  final String cashbackDestination;
  final bool linkedServicesEnabled;
}

final class AccountPreferences {
  const AccountPreferences({
    this.name,
    this.autoTopUp,
    this.roundUp,
    this.charity,
    this.cashbackDestination,
    this.extraCard,
    this.frozenCardId,
    this.frozen,
    this.limitCardId,
    this.monthlyLimitMinor,
    this.linkedServicesEnabled,
  });
  final String? name;
  final bool? autoTopUp;
  final bool? roundUp;
  final bool? charity;
  final String? cashbackDestination;
  final bool? extraCard;
  final String? frozenCardId;
  final bool? frozen;
  final String? limitCardId;
  final int? monthlyLimitMinor;
  final bool? linkedServicesEnabled;
}

enum AccountOperationKind { topUp, transfer, phoneTransfer }

final class AccountRecipient {
  const AccountRecipient({
    required this.id,
    required this.name,
    required this.bank,
    required this.phone,
  });
  final String id, name, bank, phone;
}

/// The bank refused the operation. [serverMessage] is its explanation in the
/// language of the request, when it gave one.
final class AccountOperationRejected implements Exception {
  const AccountOperationRejected([this.serverMessage]);
  final String? serverMessage;

  @override
  String toString() => 'AccountOperationRejected';
}

final class AccountOperation {
  const AccountOperation({
    required this.requestId,
    required this.kind,
    required this.accountId,
    required this.amount,
    this.destinationId,
  });
  final String requestId;
  final AccountOperationKind kind;
  final String accountId;
  final Money amount;
  final String? destinationId;
}

final class AccountOperationResult {
  const AccountOperationResult({
    required this.id,
    required this.requestId,
    required this.amount,
  });
  final String id;
  final String requestId;
  final Money amount;
}

abstract interface class AccountManagement {
  Future<AccountProfile?> cachedProfile(String accountId);
  Future<AccountProfile> profile(String accountId);
  Future<AccountProfile> update(
    String accountId,
    AccountPreferences preferences,
  );
  Future<AccountOperationResult> execute(AccountOperation operation);
  Future<List<AccountRecipient>> recipients(String accountId);
  void close();
}

/// One unresolved submission per account survives route and process restarts.
abstract interface class AccountOperationJournal {
  Future<AccountOperation?> load(String accountId);
  Future<AccountOperation> reserve(AccountOperation operation);
  Future<void> clear(AccountOperation operation);
}

final class CardRequisites {
  const CardRequisites({
    required this.number,
    required this.expiry,
    required this.cvc,
  });
  final String number, expiry, cvc;
}
