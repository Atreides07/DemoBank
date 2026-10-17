import 'package:bank_core/bank_core.dart';

import 'json_fields.dart';

AccountProfile decodeAccountProfile(Map<String, dynamic> json) {
  final currency = json.string('currency');
  return AccountProfile(
    id: json.string('id'),
    name: json.string('name'),
    cashback: Money(json.integer('cashbackMinor'), currency: currency),
    cashbackDate: json.dateTime('cashbackDate'),
    contract: json.string('contract'),
    requisites: json.stringMap('requisites'),
    cards: [
      for (final card in json.objects('cards'))
        AccountCard(
          id: card.string('id'),
          lastDigits: card.string('lastDigits'),
          frozen: card.boolean('frozen'),
        ),
    ],
    limits: [
      for (final limit in json.objects('limits'))
        AccountLimit(
          id: limit.string('id'),
          title: limit.string('title'),
          limit: Money(limit.integer('limitMinor'), currency: currency),
          remaining: Money(limit.integer('remainingMinor'), currency: currency),
        ),
    ],
    autoTopUp: json.boolean('autoTopUp'),
    roundUp: json.boolean('roundUp'),
    charity: json.boolean('charity'),
    cashbackDestination: json.string('cashbackDestination'),
    linkedServicesEnabled: json.boolean('linkedServicesEnabled'),
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
