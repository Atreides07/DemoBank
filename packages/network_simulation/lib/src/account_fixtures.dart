part of 'demo_api.dart';

extension _AccountFixtures on DemoApi {
  int _pendingHold(String accountId) => _payments.values
      .where(
        (p) =>
            p['status'] == 'pending' &&
            (p['_quote'] as Map)['_accountId'] == accountId,
      )
      .fold<int>(
        0,
        (sum, p) => sum + (p['amountMinor'] as int) + (p['feeMinor'] as int),
      );
  int _spendable(String accountId) =>
      _findAccount(accountId)?['availableMinor'] as int? ?? 0;
  Map<String, dynamic>? _findAccount(String id) =>
      (_accounts().body['accounts'] as List)
          .cast<Map<String, dynamic>>()
          .where((a) => a['id'] == id)
          .firstOrNull;

  Future<SimulatedResponse?> _accountRoute(SimulatedRequest request) async {
    final parts = request.path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length == 5 &&
        parts.first == 'accounts' &&
        parts[2] == 'cards' &&
        parts.last == 'requisites' &&
        request.method == 'GET') {
      final account = _findAccount(parts[1]);
      if (account == null) {
        return _error(404, 'account_not_found', 'error.accountNotFound');
      }
      final card = (_accountProfile(parts[1]).body['cards'] as List)
          .where((c) => c['id'] == parts[3])
          .firstOrNull;
      if (card == null) {
        return _error(404, 'invalid_card', 'error.cardNotFound');
      }
      return SimulatedResponse({
        'number': '0000 0000 0000 ${card['lastDigits']}',
        'expiry': '12/29',
        'cvc': '000',
      });
    }
    if (parts.length != 3 || parts.first != 'accounts') return null;
    final id = parts[1];
    if (_findAccount(id) == null) {
      return _error(404, 'account_not_found', 'error.accountNotFound');
    }
    if (request.method == 'GET' && parts.last == 'recipients') {
      return SimulatedResponse({
        'items': [
          for (final (recipient, phone) in const [
            ('demo-anna', '+7 (000) 000-00-11'),
            ('demo-ivan', '+7 (000) 000-00-22'),
            ('demo-maria', '+7 (000) 000-00-33'),
          ])
            {
              'id': recipient,
              'name': _t('recipient.$recipient'),
              'bank': _t('bank.$recipient'),
              'phone': phone,
            },
        ],
      });
    }
    if (request.method == 'GET' && parts.last == 'profile') {
      return _accountProfile(id);
    }
    if (request.method == 'POST' && parts.last == 'preferences') {
      const allowed = {
        'name',
        'autoTopUp',
        'roundUp',
        'charity',
        'cashbackDestination',
        'extraCard',
        'frozenCardId',
        'frozen',
        'limitCardId',
        'monthlyLimitMinor',
        'linkedServicesEnabled',
      };
      if (request.body.keys.any((key) => !allowed.contains(key))) {
        return _error(422, 'invalid_preference', 'error.unknownSetting');
      }
      final patch = Map<String, dynamic>.from(request.body);
      if (patch.containsKey('name')) {
        final name = patch['name'];
        if (name is! String || name.trim().isEmpty || name.trim().length > 32) {
          return _error(422, 'invalid_name', 'error.nameLength');
        }
        patch['name'] = name.trim();
      }
      for (final key in [
        'autoTopUp',
        'roundUp',
        'charity',
        'extraCard',
        'frozen',
        'linkedServicesEnabled',
      ]) {
        if (patch.containsKey(key) && patch[key] is! bool) {
          return _error(422, 'invalid_preference', 'error.invalidSetting');
        }
      }
      if (patch.containsKey('cashbackDestination')) {
        final target = _findAccount(patch['cashbackDestination'].toString());
        if (target == null ||
            target['currency'] != _findAccount(id)!['currency']) {
          return _error(422, 'invalid_destination', 'error.cashbackCurrency');
        }
      }
      final limitCard = patch['limitCardId'];
      if (patch.containsKey('limitCardId') ||
          patch.containsKey('monthlyLimitMinor')) {
        final limit = patch['monthlyLimitMinor'];
        final cards = _accountProfile(id).body['cards'] as List;
        if (limitCard is! String ||
            !cards.any((c) => c['id'] == limitCard) ||
            limit is! int ||
            limit < 0 ||
            limit > 999999999) {
          return _error(422, 'invalid_card_limit', 'error.invalidSetting');
        }
      }
      final preferences = _accountPreferences.putIfAbsent(id, () => {});
      if (patch.containsKey('frozenCardId')) {
        final cardId = patch.remove('frozenCardId');
        final cards = _accountProfile(id).body['cards'] as List;
        if (!cards.any((c) => (c as Map)['id'] == cardId) ||
            patch['frozen'] is! bool) {
          return _error(422, 'invalid_card', 'error.cardNotFound');
        }
        preferences['frozen:$cardId'] = patch.remove('frozen');
      } else if (patch.containsKey('frozen')) {
        return _error(422, 'invalid_card', 'error.chooseCard');
      }
      if (limitCard != null) {
        preferences['limit:$limitCard'] = patch.remove('monthlyLimitMinor');
        patch.remove('limitCardId');
      }
      preferences.addAll(patch);
      await _persist();
      return _accountProfile(id);
    }
    if (request.method == 'POST' && parts.last == 'operations') {
      return _executeAccountOperation(id, request.body);
    }
    return null;
  }

  SimulatedResponse _accountProfile(String id) {
    final account = _findAccount(id)!;
    final prefs = _accountPreferences[id] ?? const <String, dynamic>{};
    final digits = id == 'main'
        ? [
            '4821',
            '9364',
            if (prefs['extraCard'] == true) '6057' else null,
            '3178',
            '8246',
            '5903',
          ]
        : [account['lastDigits'] as String];
    if (id != 'main' && prefs['extraCard'] == true) digits.add('6057');
    return SimulatedResponse({
      'id': id,
      'name': account['name'],
      'cashbackMinor': switch (id) {
        'main' => 12480,
        'uzs' => 1250000,
        _ => 3850,
      },
      'currency': account['currency'],
      'cashbackDate': '2026-10-22T00:00:00.000Z',
      'contract': id == 'main' ? 'DEMO-2026-0042' : 'DEMO-2026-0097',
      'requisites': {
        _t('requisites.recipient'): _t('customer.name'),
        _t('requisites.bank'): _t('requisites.bankValue'),
        _t('requisites.account'): id == 'main'
            ? '00000000000000000042'
            : '00000000000000000097',
        _t('requisites.bic'): '000000000',
        _t('requisites.currency'): account['currency'],
      },
      'cards': [
        for (var i = 0; i < digits.length; i++)
          if (digits[i] != null)
            {
              'id': '$id-card-$i',
              'lastDigits': digits[i],
              'frozen': prefs['frozen:$id-card-$i'] ?? false,
              'monthlyLimitMinor': prefs['limit:$id-card-$i'] ?? 10000000,
            },
      ],
      'limits': [
        for (final (limitId, limit, remaining) in const [
          ('other_atm', 10000000, 7500000),
          ('own_atm', 50000000, 42000000),
          ('transfers', 100000000, 93500000),
        ])
          {
            'id': limitId,
            'title': _t('limit.$limitId'),
            'limitMinor': limit,
            'remainingMinor': remaining,
          },
      ],
      'autoTopUp': prefs['autoTopUp'] ?? false,
      'roundUp': prefs['roundUp'] ?? false,
      'charity': prefs['charity'] ?? false,
      'cashbackDestination': prefs['cashbackDestination'] ?? id,
      'linkedServicesEnabled': prefs['linkedServicesEnabled'] ?? true,
    });
  }

  Future<SimulatedResponse> _executeAccountOperation(
    String id,
    Map<String, dynamic> body,
  ) async {
    final key = body['requestId'];
    if (key is! String || key.isEmpty || key.length > 120) {
      return _error(422, 'missing_request_id', 'error.noOperationKey');
    }
    final signature = jsonEncode([
      id,
      body['kind'],
      body['amountMinor'],
      body['currency'],
      body['destinationId'],
    ]);
    final previous = _accountOperations[key];
    if (previous != null) {
      return previous['_signature'] == signature
          ? SimulatedResponse(_public(previous))
          : _error(409, 'request_conflict', 'error.keyConflict');
    }
    final amount = body['amountMinor'];
    if (amount is! int || amount <= 0 || amount > 100000000) {
      return _error(422, 'invalid_amount', 'error.operationAmount');
    }
    final account = _findAccount(id)!;
    if (body['currency'] != account['currency']) {
      return _error(422, 'currency_mismatch', 'error.currencyMismatch');
    }
    final kind = body['kind'];
    if (kind != 'topUp' && kind != 'transfer' && kind != 'phoneTransfer') {
      return _error(422, 'invalid_operation', 'error.unsupportedOperation');
    }
    final destination = body['destinationId'];
    if (kind == 'phoneTransfer' &&
        (account['currency'] != 'RUB' ||
            !['demo-anna', 'demo-ivan', 'demo-maria'].contains(destination))) {
      return _error(422, 'invalid_recipient', 'error.phoneRecipient');
    }
    if (kind != 'topUp' && _spendable(id) < amount) {
      return _error(422, 'insufficient_funds', 'error.notEnough');
    }
    if (kind == 'transfer') {
      final target = destination is String ? _findAccount(destination) : null;
      if (target == null ||
          destination == id ||
          target['currency'] != account['currency']) {
        return _error(422, 'invalid_destination', 'error.otherAccount');
      }
      if (_spendable(id) < amount) {
        return _error(422, 'insufficient_funds', 'error.notEnough');
      }
    }
    final operationId = 'account-${_accountOperations.length + 1}';
    final at = _ledgerTime().toIso8601String();
    Map<String, dynamic> entry(
      String accountId,
      String suffix,
      bool incoming,
    ) => {
      'id': '$operationId-$suffix',
      '_titleKey': kind == 'topUp'
          ? 'entry.cardTopUp'
          : kind == 'phoneTransfer'
          ? 'recipient.$destination'
          : 'entry.ownTransfer',
      '_subtitleKey': kind == 'topUp'
          ? 'entry.demoTopUp'
          : incoming
          ? 'entry.incoming'
          : 'entry.outgoing',
      'amountMinor': kind != 'topUp' && !incoming ? -amount : amount,
      'currency': account['currency'],
      'occurredAt': at,
      'categoryId': 'other',
      'merchantId': 'own-accounts',
      'accountId': accountId,
      'kind': kind == 'topUp' ? 'income' : 'transfer',
      'status': 'posted',
    };
    final rows = <Map<String, dynamic>>[];
    if (kind == 'topUp') {
      _accountAdjustments[id] = (_accountAdjustments[id] ?? 0) + amount;
      rows.add(entry(id, 'credit', true));
    } else {
      _accountAdjustments[id] = (_accountAdjustments[id] ?? 0) - amount;
      rows.add(entry(id, 'debit', false));
      if (kind == 'transfer') {
        _accountAdjustments[destination as String] =
            (_accountAdjustments[destination] ?? 0) + amount;
        rows.add(entry(destination, 'credit', true));
      }
    }
    for (final row in rows) {
      _mutations[row['id'] as String] = row;
      _instants[at] = DateTime.parse(at).microsecondsSinceEpoch;
    }
    final current = _snapshots[_revision]!;
    _snapshots[++_revision] = List.unmodifiable([...rows, ...current]);
    while (_snapshots.length > 12) {
      _snapshots.remove(_snapshots.keys.first);
    }
    final result = {
      'id': operationId,
      'requestId': key,
      'amountMinor': amount,
      'currency': account['currency'],
      '_signature': signature,
    };
    _accountOperations[key] = result;
    await _persist();
    return SimulatedResponse(_public(result));
  }
}
