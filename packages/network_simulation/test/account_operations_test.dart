import 'package:network_simulation/network_simulation.dart';
import 'package:test/test.dart';

Future<SimulatedResponse> _call(
  DemoApi api,
  String path, {
  Map<String, dynamic>? body,
}) => api.handle(
  SimulatedRequest(
    method: body == null ? 'GET' : 'POST',
    uri: Uri.parse('https://demo.invalid/v1$path'),
    body: body ?? const {},
  ),
);
Future<Map<String, int>> _balances(DemoApi api) async => {
  for (final a in (await _call(api, '/accounts')).body['accounts'] as List)
    a['id'] as String: a['balanceMinor'] as int,
};
Map<String, dynamic> _operation(
  String key, {
  String kind = 'transfer',
  int amount = 12345,
  String? target = 'savings',
  String currency = 'RUB',
}) => {
  'requestId': key,
  'kind': kind,
  'amountMinor': amount,
  'currency': currency,
  'destinationId': ?target,
};
void main() {
  late DemoApi api;
  setUp(() async {
    api = DemoApi();
    await api.warmUp();
  });
  test(
    'card limits persist independently and reject invalid updates',
    () async {
      final before = await _balances(api);
      final original = (await _call(api, '/accounts/main/profile')).body;
      for (final patch in [
        {'limitCardId': 'missing', 'monthlyLimitMinor': 100},
        {'limitCardId': 'main-card-0', 'monthlyLimitMinor': -1},
        {'limitCardId': 'main-card-0', 'monthlyLimitMinor': 1.5},
        {'limitCardId': 'main-card-0', 'monthlyLimitMinor': 1000000000},
        {'monthlyLimitMinor': 100},
      ]) {
        expect(
          (await _call(
            api,
            '/accounts/main/preferences',
            body: patch,
          )).statusCode,
          422,
        );
        expect((await _call(api, '/accounts/main/profile')).body, original);
      }
      await _call(
        api,
        '/accounts/main/preferences',
        body: {'limitCardId': 'main-card-1', 'monthlyLimitMinor': 120050},
      );
      final profile = (await _call(api, '/accounts/main/profile')).body;
      final cards = profile['cards'] as List;
      expect(
        cards.singleWhere((c) => c['id'] == 'main-card-1')['monthlyLimitMinor'],
        120050,
      );
      expect(
        cards
            .where((c) => c['id'] != 'main-card-1')
            .every((c) => c['monthlyLimitMinor'] == 10000000),
        isTrue,
      );
      expect(await _balances(api), before);
      final restored = DemoApi();
      await restored.restoreState(api.exportState());
      expect((await _call(restored, '/accounts/main/profile')).body, profile);
      await _call(
        api,
        '/accounts/main/preferences',
        body: {'limitCardId': 'main-card-1', 'monthlyLimitMinor': 0},
      );
      expect(
        ((await _call(api, '/accounts/main/profile')).body['cards'] as List)
            .singleWhere((c) => c['id'] == 'main-card-1')['monthlyLimitMinor'],
        0,
      );
    },
  );

  test(
    'card history is scoped and requisites belong to selected card',
    () async {
      final sets = <Set<String>>[];
      for (final index in [0, 1, 3, 4, 5]) {
        final card = 'main-card-$index';
        final response = await _call(
          api,
          '/transactions?accounts=main&cardId=$card&limit=5',
        );
        expect(response.statusCode, 200);
        final items = response.body['items'] as List;
        expect(items, hasLength(5));
        expect(
          items.every((e) => e['cardId'] == card && e['accountId'] == 'main'),
          isTrue,
        );
        final ids = items.map((e) => e['id'] as String).toSet();
        expect(
          sets.every((previous) => previous.intersection(ids).isEmpty),
          isTrue,
        );
        sets.add(ids);
        final cursor = Uri.encodeQueryComponent(
          response.body['nextCursor'] as String,
        );
        expect(
          (await _call(
            api,
            '/transactions?accounts=main&cardId=missing&cursor=$cursor&limit=5',
          )).statusCode,
          400,
        );
      }
      final details = await _call(
        api,
        '/accounts/main/cards/main-card-1/requisites',
      );
      expect(details.body['number'], '0000 0000 0000 9364');
      expect(
        (await _call(
          api,
          '/accounts/main/cards/missing/requisites',
        )).statusCode,
        404,
      );
      expect(
        (await _call(
          api,
          '/accounts/savings/cards/main-card-1/requisites',
        )).statusCode,
        404,
      );
      expect(
        ((await _call(api, '/accounts/main/profile')).body['cards'] as List)
            .any(
              (c) =>
                  c.containsKey('cvc') == true ||
                  c.containsKey('number') == true,
            ),
        isFalse,
      );
    },
  );

  test(
    'own transfer is atomic, exact, idempotent and excluded from expenses',
    () async {
      expect(
        (await _call(api, '/accounts/main/profile')).body['cards'],
        hasLength(5),
      );
      final before = await _balances(api);
      final expenses = (await _call(
        api,
        '/analytics?accounts=main',
      )).body['totalMinor'];
      final results = await Future.wait(
        List.generate(
          6,
          (_) =>
              _call(api, '/accounts/main/operations', body: _operation('same')),
        ),
      );
      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(results.map((r) => r.body['id']).toSet(), hasLength(1));
      final after = await _balances(api);
      expect(after['main'], before['main']! - 12345);
      expect(after['savings'], before['savings']! + 12345);
      expect(
        after.values.reduce((a, b) => a + b),
        before.values.reduce((a, b) => a + b),
      );
      final main = (await _call(
        api,
        '/transactions?accounts=main&kind=transfer',
      )).body;
      final outgoing = (main['items'] as List).firstWhere(
        (r) => r['id'] == 'account-1-debit',
      );
      expect(outgoing['amountMinor'], -12345);
      final incoming =
          ((await _call(
                    api,
                    '/transactions?accounts=savings&kind=transfer',
                  )).body['items']
                  as List)
              .firstWhere((r) => r['id'] == 'account-1-credit');
      expect(incoming['amountMinor'], 12345);
      expect(
        (await _call(api, '/analytics?accounts=main')).body['totalMinor'],
        expenses,
      );
      final conflict = await _call(
        api,
        '/accounts/main/operations',
        body: _operation('same', amount: 1),
      );
      expect(conflict.statusCode, 409);
      expect(await _balances(api), after);
    },
  );
  test(
    'pending payments reserve funds against transfers and later payment submissions',
    () async {
      final initial = await _balances(api);
      final quote = await _call(
        api,
        '/checkout/quotes',
        body: {
          'kind': 'mobile',
          'accountId': 'main',
          'recipient': 'Учебная связь',
          'referenceIds': ['mts'],
          'currency': 'RUB',
          'amountMinor': 10000,
          'details': {'phone': '79160000000', 'operatorId': 'mts'},
        },
      );
      expect(quote.statusCode, 200);
      api.pendingNextPayment = true;
      final payment = await _call(
        api,
        '/checkout/payments',
        body: {
          'quoteId': quote.body['id'],
          'idempotencyKey': 'pending-reservation-test',
        },
      );
      expect(payment.body['status'], 'pending');
      final account =
          ((await _call(api, '/accounts')).body['accounts'] as List).first;
      expect(account['balanceMinor'], initial['main']);
      expect(account['availableMinor'], initial['main']! - 10000);
      expect(
        (await _call(
          api,
          '/accounts/main/operations',
          body: _operation('overspend', amount: initial['main']! - 9999),
        )).statusCode,
        422,
      );
      expect(
        (await _call(
          api,
          '/accounts/main/operations',
          body: _operation('remaining', amount: initial['main']! - 10000),
        )).statusCode,
        200,
      );
      final rejected = await _call(
        api,
        '/checkout/quotes',
        body: {
          'kind': 'mobile',
          'accountId': 'main',
          'recipient': 'Учебная связь',
          'referenceIds': ['mts'],
          'currency': 'RUB',
          'amountMinor': 10000,
          'details': {'phone': '79160000000', 'operatorId': 'mts'},
        },
      );
      expect(rejected.statusCode, 422);
      await api.settlePendingPayments();
      expect((await _balances(api))['main'], 0);
    },
  );
  test('topup uses the account currency and adds exactly one income', () async {
    final before = await _balances(api);
    final result = await _call(
      api,
      '/accounts/usd/operations',
      body: _operation(
        'usd-topup',
        kind: 'topUp',
        target: null,
        amount: 10001,
        currency: 'USD',
      ),
    );
    expect(result.statusCode, 200);
    expect((await _balances(api))['usd'], before['usd']! + 10001);
    final ledger = (await _call(
      api,
      '/transactions?accounts=usd&currency=USD',
    )).body;
    expect(ledger['total'], 1);
    expect((ledger['items'] as List).single['kind'], 'income');
  });
  test(
    'phone transfer debits only source; unknown and real contacts are rejected',
    () async {
      final before = await _balances(api);
      final contacts =
          (await _call(api, '/accounts/main/recipients')).body['items'] as List;
      expect(contacts, hasLength(3));
      expect(
        contacts.every((r) => (r['phone'] as String).contains('(000)')),
        isTrue,
      );
      final result = await _call(
        api,
        '/accounts/main/operations',
        body: _operation('phone', kind: 'phoneTransfer', target: 'demo-anna'),
      );
      expect(result.statusCode, 200);
      final after = await _balances(api);
      expect(after['main'], before['main']! - 12345);
      expect(after['savings'], before['savings']);
      final bad = await _call(
        api,
        '/accounts/main/operations',
        body: _operation(
          'real-phone',
          kind: 'phoneTransfer',
          target: '+79991234567',
        ),
      );
      expect(bad.statusCode, 422);
      expect(await _balances(api), after);
    },
  );
  test(
    'invalid amount, cross currency, self transfer and insufficient funds never mutate',
    () async {
      final before = await _balances(api);
      for (final body in [
        _operation('zero', amount: 0),
        _operation('negative', amount: -1),
        _operation('fraction')..['amountMinor'] = 1.1,
        _operation('currency', currency: 'USD'),
        _operation('cross', target: 'usd'),
        _operation('self', target: 'main'),
        _operation('large', amount: before['main']! + 1),
      ]) {
        expect(
          (await _call(
            api,
            '/accounts/main/operations',
            body: body,
          )).statusCode,
          422,
        );
        expect(await _balances(api), before);
      }
    },
  );
  test(
    'preferences and completed keys survive persistence, including renamed profile',
    () async {
      await _call(
        api,
        '/accounts/main/preferences',
        body: {
          'name': 'Семейный',
          'roundUp': true,
          'extraCard': true,
          'autoTopUp': true,
          'charity': true,
          'frozenCardId': 'main-card-0',
          'frozen': true,
        },
      );
      final profile = (await _call(api, '/accounts/main/profile')).body;
      expect(profile['name'], 'Семейный');
      expect(profile['cards'], hasLength(6));
      expect((profile['cards'] as List).first['frozen'], isTrue);
      await _call(
        api,
        '/accounts/main/operations',
        body: _operation('durable'),
      );
      final restored = DemoApi();
      await restored.restoreState(api.exportState());
      expect((await _call(restored, '/accounts/main/profile')).body, profile);
      final before = await _balances(restored);
      expect(
        (await _call(
          restored,
          '/accounts/main/operations',
          body: _operation('durable'),
        )).body['id'],
        'account-1',
      );
      expect(await _balances(restored), before);
      expect(
        (await _call(
          restored,
          '/accounts/main/preferences',
          body: {'name': ''},
        )).statusCode,
        422,
      );
      expect((await _call(restored, '/accounts/main/profile')).body, profile);
    },
  );
}
