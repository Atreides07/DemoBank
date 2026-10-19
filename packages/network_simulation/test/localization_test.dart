import 'package:network_simulation/network_simulation.dart';
import 'package:test/test.dart';

final _cyrillic = RegExp('[Ѐ-ӿ]');

Future<SimulatedResponse> _send(
  DemoApi api,
  String path, {
  String? language,
  String method = 'GET',
  Map<String, dynamic> body = const {},
}) => api.handle(
  SimulatedRequest(
    method: method,
    uri: Uri.parse('https://demo.invalid/v1$path'),
    body: body,
    acceptLanguage: language,
  ),
);

Future<Map<String, dynamic>> _get(
  DemoApi api,
  String path, {
  String? language,
}) async {
  final response = await _send(api, path, language: language);
  expect(response.statusCode, 200, reason: response.body.toString());
  return response.body;
}

/// Every string in a response, at any depth.
Iterable<String> _strings(Object? value) sync* {
  if (value is String) {
    yield value;
  } else if (value is Map) {
    for (final entry in value.entries) {
      yield* _strings(entry.key);
      yield* _strings(entry.value);
    }
  } else if (value is List) {
    for (final item in value) {
      yield* _strings(item);
    }
  }
}

void main() {
  late DemoApi api;
  setUp(() async {
    api = DemoApi();
    await api.warmUp();
  });

  test('every text exists in every language', () {
    final keys = DemoTexts.catalogue['ru']!.keys.toSet();
    for (final language in DemoTexts.languages) {
      expect(
        DemoTexts.catalogue[language]!.keys.toSet(),
        keys,
        reason: language,
      );
    }
    for (final language in ['en', 'uz']) {
      for (final entry in DemoTexts.catalogue[language]!.entries) {
        expect(
          _cyrillic.hasMatch(entry.value),
          isFalse,
          reason: '$language: ${entry.key}',
        );
      }
    }
  });

  test('Accept-Language is negotiated by primary subtag', () {
    expect(DemoTexts.negotiate(null), 'ru');
    expect(DemoTexts.negotiate('en-GB,en;q=0.9'), 'en');
    expect(DemoTexts.negotiate('de-DE, uz-Latn-UZ;q=0.8'), 'uz');
    expect(DemoTexts.negotiate('fr'), 'ru');
  });

  for (final language in ['en', 'uz']) {
    test('$language responses carry no Russian text', () async {
      final paths = [
        '/accounts',
        '/transactions?limit=100',
        '/transactions?limit=100&accounts=uzs&currency=UZS',
        '/analytics?from=2026-10-01&to=2026-10-16',
        '/analytics?from=2026-10-01&to=2026-10-16&currency=UZS',
        '/services',
        '/services/fines?document=1234567890',
        '/services/utilities?account=1234567890',
        '/services/operators?phone=79161234567',
        '/services/movies',
        '/services/sessions?movieId=movie-001',
        '/services/seats?sessionId=movie-001-evening',
        '/accounts/main/profile',
        '/accounts/main/recipients',
      ];
      for (final path in paths) {
        final body = await _get(api, path, language: language);
        for (final text in _strings(body)) {
          expect(_cyrillic.hasMatch(text), isFalse, reason: '$path: $text');
        }
      }
      final rejected = await _send(
        api,
        '/services/operators?phone=1',
        language: language,
      );
      expect(rejected.statusCode, 422);
      expect(_cyrillic.hasMatch(rejected.body['message'] as String), isFalse);
    });
  }

  test('state is language-neutral: a payment reads in the language of '
      'whoever asks', () async {
    final quote = await _send(
      api,
      '/checkout/quotes',
      method: 'POST',
      language: 'en',
      body: {
        'kind': 'mobile',
        'accountId': 'main',
        'currency': 'RUB',
        'recipient': 'mts',
        'amountMinor': 15555,
        'details': {'phone': '79161234567', 'operatorId': 'mts'},
      },
    );
    expect(quote.statusCode, 200, reason: quote.body.toString());
    expect(quote.body['recipient'], 'MTS');
    expect(quote.body['description'], 'Mobile top-up');
    final payment = await _send(
      api,
      '/checkout/payments',
      method: 'POST',
      language: 'en',
      body: {'idempotencyKey': 'key-language-1', 'quoteId': quote.body['id']},
    );
    expect(payment.statusCode, 200, reason: payment.body.toString());

    Future<Map<String, dynamic>> newest(String language) async =>
        ((await _get(api, '/transactions?limit=1', language: language))['items']
                    as List)
                .first
            as Map<String, dynamic>;
    expect((await newest('ru'))['title'], 'МТС');
    expect((await newest('ru'))['subtitle'], 'Пополнение мобильной связи');
    expect((await newest('uz'))['subtitle'], 'Mobil aloqani toʻldirish');
  });

  test(
    'restored cinema ticket resolves session and seat IDs in each language',
    () async {
      Map<String, dynamic>? saved;
      api = DemoApi(saveState: (state) async => saved = state);
      await api.warmUp();
      final quote = await _send(
        api,
        '/checkout/quotes',
        method: 'POST',
        body: {
          'kind': 'cinema',
          'referenceIds': ['seat-6', 'seat-7'],
          'accountId': 'main',
          'recipient': 'cinema',
          'currency': 'RUB',
          'details': {'sessionId': 'movie-002-night', 'seatVersion': '1'},
        },
      );
      expect(quote.statusCode, 200);
      final payment = await _send(
        api,
        '/checkout/payments',
        method: 'POST',
        body: {
          'quoteId': quote.body['id'],
          'idempotencyKey': 'ticket-language-1',
        },
      );
      expect(payment.statusCode, 200);
      api = DemoApi(loadState: () async => saved);
      await api.warmUp();
      for (final (language, movie, firstSeat, secondSeat) in [
        ('ru', 'Город в деталях', 'Ряд 1 · место 6', 'Ряд 2 · место 1'),
        ('en', 'The City in Detail', 'Row 1 · seat 6', 'Row 2 · seat 1'),
        ('uz', 'Shahar tafsilotlari', '1-qator · 6-joy', '2-qator · 1-joy'),
      ]) {
        final status = await _get(
          api,
          '/checkout/payments/status?idempotencyKey=ticket-language-1',
          language: language,
        );
        final ticket = status['ticket'] as String;
        expect(ticket, contains(movie));
        expect(ticket, contains('17.10.2026 · 21:30 (UTC+3)'));
        expect(ticket, contains('$firstSeat, $secondSeat'));
        expect(ticket, isNot(matches(RegExp(r'(movie|seat|payment)-'))));
        expect(status['id'], payment.body['id']);
      }
    },
  );

  test(
    'the sum account has its own ledger and keeps the rouble dataset',
    () async {
      final accounts = (await _get(api, '/accounts'))['accounts'] as List;
      final uzs = accounts.cast<Map<String, dynamic>>().singleWhere(
        (account) => account['id'] == 'uzs',
      );
      expect(uzs['currency'], 'UZS');
      expect(uzs['name'], 'Сумовый счёт');
      expect(uzs['balanceMinor'], 1275000000);

      final roubles = await _get(api, '/transactions?limit=1');
      expect(roubles['total'], DemoApi.datasetSize);
      final sums = await _get(
        api,
        '/transactions?limit=100&accounts=uzs&currency=UZS',
      );
      expect(sums['total'], DemoApi.uzsDatasetSize);
      for (final item in (sums['items'] as List).cast<Map<String, dynamic>>()) {
        expect(item['currency'], 'UZS');
        expect(item['accountId'], 'uzs');
        expect((item['amountMinor'] as int) % 100000, 0, reason: 'whole sums');
      }
      final analytics = await _get(
        api,
        '/analytics?from=2026-10-01&to=2026-10-16&currency=UZS',
        language: 'uz',
      );
      expect(analytics['currency'], 'UZS');
      expect(analytics['totalMinor'], greaterThan(0));
    },
  );

  test('a renamed account keeps the name the customer typed', () async {
    final renamed = await _send(
      api,
      '/accounts/uzs/preferences',
      method: 'POST',
      body: {'name': 'Toshkent'},
    );
    expect(renamed.statusCode, 200);
    final accounts =
        (await _get(api, '/accounts', language: 'en'))['accounts'] as List;
    expect(
      accounts.cast<Map<String, dynamic>>().singleWhere(
        (account) => account['id'] == 'uzs',
      )['name'],
      'Toshkent',
    );
  });
}
