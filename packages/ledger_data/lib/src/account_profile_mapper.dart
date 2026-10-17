import 'package:bank_core/bank_core.dart';

AccountProfile decodeAccountProfile(Map<String, dynamic> json) {
  final currency = json['currency'] as String;
  return AccountProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    cashback: Money(json['cashbackMinor'] as int, currency: currency),
    cashbackDate: DateTime.parse(json['cashbackDate'] as String),
    contract: json['contract'] as String,
    requisites: Map<String, String>.from(json['requisites'] as Map),
    cards: [
      for (final value in json['cards'] as List)
        AccountCard(
          id: (value as Map)['id'] as String,
          lastDigits: value['lastDigits'] as String,
          frozen: value['frozen'] as bool,
        ),
    ],
    limits: [
      for (final value in json['limits'] as List)
        AccountLimit(
          id: (value as Map)['id'] as String,
          title: value['title'] as String,
          limit: Money(value['limitMinor'] as int, currency: currency),
          remaining: Money(value['remainingMinor'] as int, currency: currency),
        ),
    ],
    autoTopUp: json['autoTopUp'] as bool,
    roundUp: json['roundUp'] as bool,
    charity: json['charity'] as bool,
    cashbackDestination: json['cashbackDestination'] as String,
    linkedServicesEnabled: json['linkedServicesEnabled'] as bool,
  );
}

Map<String, dynamic> encodeAccountPreferences(AccountPreferences p) => {
  if (p.name != null) 'name': p.name,
  if (p.autoTopUp != null) 'autoTopUp': p.autoTopUp,
  if (p.roundUp != null) 'roundUp': p.roundUp,
  if (p.charity != null) 'charity': p.charity,
  if (p.cashbackDestination != null)
    'cashbackDestination': p.cashbackDestination,
  if (p.extraCard != null) 'extraCard': p.extraCard,
  if (p.frozenCardId != null) 'frozenCardId': p.frozenCardId,
  if (p.frozen != null) 'frozen': p.frozen,
  if (p.linkedServicesEnabled != null)
    'linkedServicesEnabled': p.linkedServicesEnabled,
};
