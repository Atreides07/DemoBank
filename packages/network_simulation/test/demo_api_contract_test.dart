import 'package:network_simulation/network_simulation.dart';
import 'package:test/test.dart';

Future<Map<String, dynamic>> request(
  DemoApi api,
  String path, {
  String method = 'GET',
  Map<String, dynamic> body = const {},
}) async {
  final response = await api.handle(
    SimulatedRequest(
      method: method,
      uri: Uri.parse('https://demo.invalid/v1$path'),
      body: body,
    ),
  );
  expect(response.statusCode, 200, reason: response.body.toString());
  return response.body;
}

void main() {
  late DemoApi api;
  setUp(() async {
    api = DemoApi();
    await api.warmUp();
  });

  test(
    '12,000 records page exactly once; next cursor owns a snapshot',
    () async {
      final ids = <String>{};
      String? cursor;
      do {
        final query = Uri(
          queryParameters: {'limit': '100', 'cursor': ?cursor},
        ).query;
        final page = await request(api, '/transactions?$query');
        for (final item in page['items'] as List) {
          expect(ids.add((item as Map)['id'] as String), isTrue);
        }
        expect(page['total'], DemoApi.datasetSize);
        cursor = page['nextCursor'] as String?;
        if (ids.length == 100) {
          await request(api, '/demo/activity', method: 'POST');
        }
      } while (cursor != null);
      expect(ids.length, DemoApi.datasetSize);
      expect(ids.any((id) => id.startsWith('txn-live')), isFalse);
      final live = await request(api, '/transactions');
      expect(live['total'], DemoApi.datasetSize + 1);
      expect(live['revision'], isNot('1'));
    },
  );

  test('filtered ledger, category, merchant and timeline totals agree', () async {
    const filters = 'from=2026-10-01&to=2026-10-16&accounts=main';
    final analytics = await request(api, '/analytics?$filters');
    final total = analytics['totalMinor'] as int;
    final categories = (analytics['categories'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      categories.fold<int>(
        0,
        (sum, item) => sum + (item['amountMinor'] as int),
      ),
      total,
    );
    final timeline = (analytics['timeline'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      timeline.fold<int>(0, (sum, item) => sum + (item['amountMinor'] as int)),
      total,
    );
    final merchants = (analytics['merchants'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      merchants.fold<int>(0, (sum, item) => sum + (item['amountMinor'] as int)),
      total,
    );
    var fullSum = 0;
    var fullCount = 0;
    String? cursor;
    do {
      final page = await request(
        api,
        '/transactions?$filters&kind=expense&limit=100'
        '${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
      );
      expect(page['totalMinor'], total);
      for (final item in (page['items'] as List).cast<Map<String, dynamic>>()) {
        expect(item['status'], 'posted');
        fullSum += item['amountMinor'] as int;
        fullCount++;
      }
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    expect(fullSum, total);
    expect(fullCount, analytics['count']);
    expect(analytics['refundMinor'], greaterThan(0));
    expect(analytics['timezone'], 'Europe/Moscow');
  });

  test(
    'empty data, zero comparison, period bounds and currency stay explicit',
    () async {
      final empty = await request(
        api,
        '/analytics?from=2030-01-01&to=2030-01-31',
      );
      expect(empty['totalMinor'], 0);
      expect(empty['count'], 0);
      expect(empty['comparisonHasData'], isFalse);
      expect((empty['timeline'] as List).length, 31);
      final boundary = {
        'id': 'usd-boundary',
        'title': 'Foreign merchant',
        'subtitle': 'Travel',
        'amountMinor': 12345,
        'currency': 'USD',
        'occurredAt': '2026-09-30T21:00:00.000Z',
        'categoryId': 'shopping',
        'merchantId': 'foreign',
        'accountId': 'main',
        'kind': 'expense',
        'status': 'posted',
      };
      api.addTransaction(boundary);
      api.addTransaction({
        ...boundary,
        'id': 'usd-excluded-end',
        'occurredAt': '2026-10-01T21:00:00.000Z',
      });
      final usd = await request(
        api,
        '/analytics?from=2026-10-01&to=2026-10-01&currency=USD',
      );
      expect(usd['totalMinor'], 12345);
      expect(usd['currency'], 'USD');
      final rub = await request(
        api,
        '/analytics?from=2026-10-01&to=2026-10-01',
      );
      expect(rub['currency'], 'RUB');
      expect(rub['totalMinor'], isNot(usd['totalMinor']));
    },
  );

  test('cursor rejects changed filters and expired revisions', () async {
    final page = await request(api, '/transactions?category=dining');
    final cursor = Uri.encodeQueryComponent(page['nextCursor'] as String);
    final invalid = await api.handle(
      SimulatedRequest(
        method: 'GET',
        uri: Uri.parse(
          'https://demo.invalid/v1/transactions?category=shopping&cursor=$cursor',
        ),
      ),
    );
    expect(invalid.statusCode, 400);
    for (var index = 0; index < 7; index++) {
      await request(api, '/demo/activity', method: 'POST');
    }
    final expired = await api.handle(
      SimulatedRequest(
        method: 'GET',
        uri: Uri.parse(
          'https://demo.invalid/v1/transactions?category=dining&cursor=$cursor',
        ),
      ),
    );
    expect(expired.statusCode, 409);
    expect(expired.body['code'], 'snapshot_expired');
  });

  test(
    'stable anchors, neighboring cursors and revision-locked seeks align pages',
    () async {
      final first = await request(api, '/transactions?limit=100');
      final anchor = ((first['items'] as List)[95] as Map)['id'] as String;
      final around = await request(
        api,
        '/transactions?anchor=$anchor&near=95&revision=1',
      );
      expect(around['startIndex'], 90);
      expect(around['anchorFound'], isTrue);
      expect(
        (around['items'] as List).any((item) => (item as Map)['id'] == anchor),
        isTrue,
      );
      final previous = await request(
        api,
        '/transactions?cursor=${Uri.encodeQueryComponent(around['prevCursor'] as String)}&revision=1',
      );
      expect(previous['startIndex'], 60);
      final sought = await request(api, '/transactions?at=600&revision=1');
      expect(sought['startIndex'], 600);
      final missing = await request(
        api,
        '/transactions?anchor=removed&near=999999&revision=1',
      );
      expect(missing['anchorFound'], isFalse);
      expect(missing['startIndex'], 11970);
      final empty = await request(
        api,
        '/transactions?category=nonexistent&anchor=removed&near=100&revision=1',
      );
      expect(empty['startIndex'], 0);
      expect(empty['total'], 0);
      final unversioned = await api.handle(
        SimulatedRequest(
          method: 'GET',
          uri: Uri.parse('https://demo.invalid/v1/transactions?at=600'),
        ),
      );
      expect(unversioned.statusCode, 400);
      expect(unversioned.body['code'], 'revision_required');
    },
  );

  test(
    'removed transactions retain old snapshots and persist as tombstones',
    () async {
      final first = await request(api, '/transactions');
      final removed = ((first['items'] as List).first as Map)['id'] as String;
      expect(api.removeTransaction(removed), isTrue);
      final old = await request(api, '/transactions?revision=1');
      expect(((old['items'] as List).first as Map)['id'], removed);
      final replacement = DemoApi();
      await replacement.restoreState(api.exportState());
      final current = await request(replacement, '/transactions');
      expect(current['total'], 11999);
      expect(((current['items'] as List).first as Map)['id'], isNot(removed));
      final window = await request(
        replacement,
        '/transactions?anchor=$removed&near=0&revision=2',
      );
      expect(window['anchorFound'], isFalse);
      expect(window['startIndex'], 0);
    },
  );

  test(
    'yearly monthly buckets progress across Moscow midnight boundaries',
    () async {
      final analytics = await request(api, '/analytics');
      final timeline = (analytics['timeline'] as List)
          .cast<Map<String, dynamic>>();
      expect(timeline.length, inInclusiveRange(12, 13));
      expect(
        timeline.fold<int>(
          0,
          (sum, item) => sum + (item['amountMinor'] as int),
        ),
        analytics['totalMinor'],
      );
      for (final bucket in timeline) {
        expect(
          DateTime.parse(
            bucket['from'] as String,
          ).isBefore(DateTime.parse(bucket['to'] as String)),
          isTrue,
        );
      }
    },
  );

  test(
    'durable simulation state restores pending payment after process replacement',
    () async {
      Map<String, dynamic>? saved;
      var saves = 0;
      api = DemoApi(
        saveState: (state) async {
          saved = state;
          saves++;
        },
      );
      api.pendingNextPayment = true;
      final quote = await request(
        api,
        '/checkout/quotes',
        method: 'POST',
        body: {
          'kind': 'fines',
          'referenceIds': ['fine-001'],
          'accountId': 'main',
          'recipient': 'Штраф',
          'currency': 'RUB',
        },
      );
      final command = {
        'quoteId': quote['id'],
        'idempotencyKey': 'restart-payment-001',
      };
      final payment = await request(
        api,
        '/checkout/payments',
        method: 'POST',
        body: command,
      );
      expect(payment['status'], 'pending');
      expect(saves, 2);
      final replaced = DemoApi(loadState: () async => saved);
      final status = await request(
        replaced,
        '/checkout/payments/status?idempotencyKey=restart-payment-001',
      );
      expect(status, payment);
      await replaced.settlePendingPayments();
      final repeated = await request(
        replaced,
        '/checkout/payments',
        method: 'POST',
        body: command,
      );
      expect(repeated['id'], payment['id']);
      expect(repeated['status'], 'succeeded');
      final ledger = await request(
        replaced,
        '/transactions?merchant=provider-fines',
      );
      expect(ledger['total'], 1);
      expect(ledger['totalMinor'], 75000);
      expect(replaced.revision, '2');
    },
  );

  test(
    'payment idempotency, fee, revision and bill change are one commit',
    () async {
      final before = await request(api, '/accounts');
      final quote = await request(
        api,
        '/checkout/quotes',
        method: 'POST',
        body: {
          'kind': 'utilities',
          'referenceIds': ['utility-001'],
          'accountId': 'main',
          'recipient': 'Городские коммунальные услуги',
          'currency': 'RUB',
          'amountMinor': 1,
          'details': {
            'billVersions': {'utility-001': '1'},
          },
        },
      );
      expect(quote['amountMinor'], 684320);
      expect(quote['feeMinor'], 1000);
      final command = {
        'quoteId': quote['id'],
        'idempotencyKey': 'test-key-00001',
      };
      final payment = await request(
        api,
        '/checkout/payments',
        method: 'POST',
        body: command,
      );
      final repeated = await request(
        api,
        '/checkout/payments',
        method: 'POST',
        body: command,
      );
      expect(repeated, payment);
      expect(payment['status'], 'succeeded');
      final status = await request(
        api,
        '/checkout/payments/status?idempotencyKey=test-key-00001',
      );
      expect(status, payment);
      expect(status.keys.any((key) => key.startsWith('_')), isFalse);
      final after = await request(api, '/accounts');
      expect(after['revision'], '2');
      final balanceBefore =
          ((before['accounts'] as List).first as Map)['balanceMinor'] as int;
      final balanceAfter =
          ((after['accounts'] as List).first as Map)['balanceMinor'] as int;
      expect(balanceBefore - balanceAfter, 685320);
      final ledger = await request(
        api,
        '/transactions?merchant=provider-utilities&kind=expense',
      );
      expect(ledger['total'], 1);
      expect(ledger['totalMinor'], 685320);
      final bills = await request(api, '/services/utilities?account=12345678');
      expect(((bills['items'] as List).first as Map)['paid'], isTrue);
      expect(((bills['items'] as List).first as Map)['version'], '2');
    },
  );

  test(
    'pending payment is restored, protected from duplicates and then settled',
    () async {
      api.pendingNextPayment = true;
      final quote = await request(
        api,
        '/checkout/quotes',
        method: 'POST',
        body: {
          'kind': 'fines',
          'referenceIds': ['fine-001'],
          'accountId': 'main',
          'recipient': 'Штраф',
          'currency': 'RUB',
        },
      );
      final payment = await request(
        api,
        '/checkout/payments',
        method: 'POST',
        body: {'quoteId': quote['id'], 'idempotencyKey': 'pending-key-001'},
      );
      expect(payment['status'], 'pending');
      final duplicate = await api.handle(
        SimulatedRequest(
          method: 'POST',
          uri: Uri.parse('https://demo.invalid/v1/checkout/payments'),
          body: {'quoteId': quote['id'], 'idempotencyKey': 'another-key-001'},
        ),
      );
      expect(duplicate.statusCode, 409);
      await api.settlePendingPayments();
      await api.settlePendingPayments();
      final restored = await request(
        api,
        '/checkout/payments/status?idempotencyKey=pending-key-001',
      );
      expect(restored['status'], 'succeeded');
      expect(api.revision, '2');
    },
  );

  test(
    'seat availability is revalidated at confirmation; quote expiry uses clock',
    () async {
      var now = DateTime.utc(2026, 10, 16, 12);
      api = DemoApi(now: () => now);
      await api.warmUp();
      final body = {
        'kind': 'cinema',
        'referenceIds': ['seat-1'],
        'accountId': 'main',
        'recipient': 'Кинотеатр «Сфера»',
        'currency': 'RUB',
        'details': {'sessionId': 'movie-001-evening', 'seatVersion': '1'},
      };
      final first = await request(
        api,
        '/checkout/quotes',
        method: 'POST',
        body: body,
      );
      final second = await request(
        api,
        '/checkout/quotes',
        method: 'POST',
        body: body,
      );
      final payment = await request(
        api,
        '/checkout/payments',
        method: 'POST',
        body: {'quoteId': first['id'], 'idempotencyKey': 'seat-key-00001'},
      );
      expect(payment['ticket'], contains('seat-1'));
      final conflict = await api.handle(
        SimulatedRequest(
          method: 'POST',
          uri: Uri.parse('https://demo.invalid/v1/checkout/payments'),
          body: {'quoteId': second['id'], 'idempotencyKey': 'seat-key-00002'},
        ),
      );
      expect(conflict.statusCode, 409);
      expect(conflict.body['code'], 'seat_conflict');
      now = now.add(const Duration(minutes: 6));
      final expired = await api.handle(
        SimulatedRequest(
          method: 'POST',
          uri: Uri.parse('https://demo.invalid/v1/checkout/payments'),
          body: {'quoteId': second['id'], 'idempotencyKey': 'seat-key-00003'},
        ),
      );
      expect(expired.body['code'], 'quote_expired');
    },
  );
}
