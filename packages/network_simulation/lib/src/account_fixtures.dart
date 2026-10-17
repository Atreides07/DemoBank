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
    if (parts.length != 3 || parts.first != 'accounts') return null;
    final id = parts[1];
    if (_findAccount(id) == null) {
      return _error(404, 'account_not_found', 'Счёт не найден');
    }
    if (request.method == 'GET' && parts.last == 'recipients') {
      return const SimulatedResponse({
        'items': [
          {
            'id': 'demo-anna',
            'name': 'Анна Демо',
            'bank': 'Учебный банк',
            'phone': '+7 (000) 000-00-11',
          },
          {
            'id': 'demo-ivan',
            'name': 'Иван Примеров',
            'bank': 'Банк примеров',
            'phone': '+7 (000) 000-00-22',
          },
          {
            'id': 'demo-maria',
            'name': 'Мария Макетова',
            'bank': 'Демо Банк',
            'phone': '+7 (000) 000-00-33',
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
        'linkedServicesEnabled',
      };
      if (request.body.keys.any((key) => !allowed.contains(key))) {
        return _error(422, 'invalid_preference', 'Неизвестная настройка');
      }
      final patch = Map<String, dynamic>.from(request.body);
      if (patch.containsKey('name')) {
        final name = patch['name'];
        if (name is! String || name.trim().isEmpty || name.trim().length > 32) {
          return _error(422, 'invalid_name', 'Название: от 1 до 32 символов');
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
          return _error(422, 'invalid_preference', 'Некорректная настройка');
        }
      }
      if (patch.containsKey('cashbackDestination')) {
        final target = _findAccount(patch['cashbackDestination'].toString());
        if (target == null ||
            target['currency'] != _findAccount(id)!['currency']) {
          return _error(
            422,
            'invalid_destination',
            'Выберите счёт зачисления в той же валюте',
          );
        }
      }
      final preferences = _accountPreferences.putIfAbsent(id, () => {});
      if (patch.containsKey('frozenCardId')) {
        final cardId = patch.remove('frozenCardId');
        final cards = _accountProfile(id).body['cards'] as List;
        if (!cards.any((c) => (c as Map)['id'] == cardId) ||
            patch['frozen'] is! bool) {
          return _error(422, 'invalid_card', 'Карта не найдена');
        }
        preferences['frozen:$cardId'] = patch.remove('frozen');
      } else if (patch.containsKey('frozen')) {
        return _error(422, 'invalid_card', 'Выберите карту');
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
        ? ['4821', '9364']
        : [account['lastDigits'] as String];
    if (prefs['extraCard'] == true) digits.add('6057');
    return SimulatedResponse({
      'id': id,
      'name': account['name'],
      'cashbackMinor': id == 'main' ? 12480 : 3850,
      'currency': account['currency'],
      'cashbackDate': '2026-10-22T00:00:00.000Z',
      'contract': id == 'main' ? 'DEMO-2026-0042' : 'DEMO-2026-0097',
      'requisites': {
        'Получатель': 'Алексей Демонов',
        'Банк': 'Демо Банк · учебные реквизиты',
        'Номер счёта': id == 'main'
            ? '00000000000000000042'
            : '00000000000000000097',
        'БИК': '000000000',
        'Валюта': account['currency'],
      },
      'cards': [
        for (var i = 0; i < digits.length; i++)
          {
            'id': '$id-card-$i',
            'lastDigits': digits[i],
            'frozen': prefs['frozen:$id-card-$i'] ?? false,
          },
      ],
      'limits': [
        {
          'id': 'other_atm',
          'title': 'Снятие в других банкоматах',
          'limitMinor': 10000000,
          'remainingMinor': 7500000,
        },
        {
          'id': 'own_atm',
          'title': 'Снятие в банкоматах Демо',
          'limitMinor': 50000000,
          'remainingMinor': 42000000,
        },
        {
          'id': 'transfers',
          'title': 'Переводы по номеру телефона',
          'limitMinor': 100000000,
          'remainingMinor': 93500000,
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
      return _error(422, 'missing_request_id', 'Нет ключа операции');
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
          : _error(
              409,
              'request_conflict',
              'Ключ уже используется другой операцией',
            );
    }
    final amount = body['amountMinor'];
    if (amount is! int || amount <= 0 || amount > 100000000) {
      return _error(
        422,
        'invalid_amount',
        'Сумма должна быть от 0,01 до 1 000 000 ₽',
      );
    }
    final account = _findAccount(id)!;
    if (body['currency'] != account['currency']) {
      return _error(
        422,
        'currency_mismatch',
        'Валюта операции не совпадает со счётом',
      );
    }
    final kind = body['kind'];
    if (kind != 'topUp' && kind != 'transfer' && kind != 'phoneTransfer') {
      return _error(422, 'invalid_operation', 'Операция не поддерживается');
    }
    final destination = body['destinationId'];
    if (kind == 'phoneTransfer' &&
        (account['currency'] != 'RUB' ||
            !['demo-anna', 'demo-ivan', 'demo-maria'].contains(destination))) {
      return _error(
        422,
        'invalid_recipient',
        'Выберите учебного получателя для рублёвого перевода',
      );
    }
    if (kind != 'topUp' && _spendable(id) < amount) {
      return _error(422, 'insufficient_funds', 'Недостаточно средств');
    }
    if (kind == 'transfer') {
      final target = destination is String ? _findAccount(destination) : null;
      if (target == null ||
          destination == id ||
          target['currency'] != account['currency']) {
        return _error(
          422,
          'invalid_destination',
          'Выберите другой счёт в той же валюте',
        );
      }
      if (_spendable(id) < amount) {
        return _error(422, 'insufficient_funds', 'Недостаточно средств');
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
      'title': kind == 'topUp'
          ? 'Пополнение с демо-карты'
          : kind == 'phoneTransfer'
          ? const {
              'demo-anna': 'Анна Демо',
              'demo-ivan': 'Иван Примеров',
              'demo-maria': 'Мария Макетова',
            }[destination]
          : 'Между своими счетами',
      'subtitle': kind == 'topUp'
          ? 'Демонстрационное пополнение'
          : incoming
          ? 'Входящий перевод'
          : 'Исходящий перевод',
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
