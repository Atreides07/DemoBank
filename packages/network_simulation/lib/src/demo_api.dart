import 'dart:async';
import 'dart:convert';
import 'dart:math';

part 'account_fixtures.dart';
part 'demo_texts.dart';

typedef DemoRoute =
    Future<SimulatedResponse?> Function(SimulatedRequest request);
typedef LoadDemoState = Future<Map<String, dynamic>?> Function();
typedef SaveDemoState = Future<void> Function(Map<String, dynamic> state);

final class SimulatedRequest {
  const SimulatedRequest({
    required this.method,
    required this.uri,
    this.body = const {},
    this.acceptLanguage,
  });

  final String method;
  final Uri uri;
  final Map<String, dynamic> body;

  /// The client's `Accept-Language`; texts in the response follow it.
  final String? acceptLanguage;

  /// The negotiated response language: `ru`, `en` or `uz`.
  String get language => DemoTexts.negotiate(acceptLanguage);
  String get path => uri.path.replaceFirst(RegExp(r'^/v1(?=/)'), '');
  Map<String, String> get query => uri.queryParameters;
}

final class SimulatedResponse {
  const SimulatedResponse(this.body, {this.statusCode = 200});

  final Map<String, dynamic> body;
  final int statusCode;
}

/// Stateful fixtures sit behind a route contract; the transport adapter knows
/// nothing about accounts, invoices, filtering, or payment rules.
final class DemoApi {
  DemoApi({
    DateTime Function()? now,
    this.routes = const [],
    this.loadState,
    this.saveState,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  /// The synthetic bank's "today": 15:00 MSK on 16 October 2026, right after
  /// the newest fixture. Clients derive reporting periods from it, and rows
  /// created at runtime are dated just after it, so a new payment always lands
  /// in the current period whatever the device's wall clock says. The wall
  /// clock passed as `now` still governs quote expiry and payment metadata.
  static final businessNow = DateTime.utc(2026, 10, 16, 12);

  static const reportTimezone = 'Europe/Moscow';

  /// Rouble ledger rows; the sum account adds [uzsDatasetSize] of its own.
  static const datasetSize = 12000;
  static const uzsDatasetSize = 600;
  static const categories = [
    'groceries',
    'transport',
    'dining',
    'shopping',
    'utilities',
    'health',
    'entertainment',
    'other',
  ];
  static const _languageKey = #demoApiLanguage;

  final DateTime Function() _now;
  final List<DemoRoute> routes;
  final LoadDemoState? loadState;
  final SaveDemoState? saveState;
  Future<void> _persistence = Future<void>.value();
  final Map<String, Map<String, dynamic>> _mutations = {};
  final Map<String, int> _instants = {};
  Future<void>? _initializing;
  int _revision = 1;
  final Map<int, List<Map<String, dynamic>>> _snapshots = {};
  final Map<String, Map<String, dynamic>> _quotes = {};
  final Map<String, Map<String, dynamic>> _payments = {};
  final Map<String, int> _accountAdjustments = {};
  final Map<String, Map<String, dynamic>> _accountPreferences = {};
  final Map<String, Map<String, dynamic>> _accountOperations = {};
  final Set<String> _paidBills = {};
  final Set<String> _reservedSeats = {};
  int _seatRevision = 1;
  int _quoteSequence = 0;
  int _paymentSequence = 0;
  int _demoSequence = 0;
  int _ledgerSequence = 0;
  bool pendingNextPayment = false;

  String get revision => '$_revision';

  Future<void> reset() async {
    await _persistence;
    _initializing = null;
    _revision = 1;
    _snapshots.clear();
    _quotes.clear();
    _payments.clear();
    _accountAdjustments.clear();
    _accountPreferences.clear();
    _accountOperations.clear();
    _paidBills.clear();
    _reservedSeats.clear();
    _mutations.clear();
    _instants.clear();
    _seatRevision = 1;
    _quoteSequence = 0;
    _paymentSequence = 0;
    _demoSequence = 0;
    _ledgerSequence = 0;
    pendingNextPayment = false;
    _initializing = _generateData(restoreSavedState: false);
    await _initializing;
    await _persist();
  }

  Future<void> _ensureData() => _initializing ??= _generateData();

  /// Timestamp of a ledger row created at runtime: strictly increasing on the
  /// demo calendar and persisted with the state, so rows keep their order
  /// across restarts.
  DateTime _ledgerTime() =>
      businessNow.add(Duration(seconds: ++_ledgerSequence));

  Future<void> warmUp() => _ensureData();

  /// Rows are stored without display text: titles and subtitles are named in
  /// the request language from the row's kind, merchant and category (see
  /// [_entryJson]).
  Future<void> _generateData({bool restoreSavedState = true}) async {
    final random = Random(76129);
    final end = DateTime.utc(2026, 10, 16, 11, 59);
    final spanSeconds = end
        .difference(DateTime.utc(2025, 10, 16, 21))
        .inSeconds;
    final result = <Map<String, dynamic>>[];
    const keys = categories;
    for (var index = 0; index < datasetSize; index++) {
      final category = keys[random.nextInt(keys.length)];
      final merchantIndex = random.nextInt(3);
      final kind = index % 47 == 0
          ? 'refund'
          : index % 31 == 0
          ? 'income'
          : index % 29 == 0
          ? 'transfer'
          : 'expense';
      final status = index % 113 == 0
          ? 'cancelled'
          : index % 97 == 0
          ? 'pending'
          : 'posted';
      final date = end.subtract(
        Duration(seconds: (index * spanSeconds) ~/ datasetSize),
      );
      final timestamp = date.toIso8601String();
      _instants[timestamp] = date.microsecondsSinceEpoch;
      result.add({
        'id': 'txn-${(datasetSize - index).toString().padLeft(6, '0')}',
        'amountMinor': 9900 + random.nextInt(480001),
        'currency': 'RUB',
        'occurredAt': timestamp,
        'categoryId': category,
        'merchantId': '$category-$merchantIndex',
        'accountId': index % 5 == 0 ? 'savings' : 'main',
        'kind': kind,
        'status': status,
      });
      // Generating large fixtures yields to event delivery; application startup
      // never waits for the entire history to be materialized synchronously.
      if (index % 500 == 499) await Future<void>.delayed(Duration.zero);
    }
    // The sum account has its own generator, so the rouble dataset stays
    // byte-for-byte what it was before the account existed.
    final uzs = Random(998);
    for (var index = 0; index < uzsDatasetSize; index++) {
      final category = keys[uzs.nextInt(keys.length)];
      final merchantIndex = uzs.nextInt(3);
      final kind = index % 37 == 0
          ? 'refund'
          : index % 23 == 0
          ? 'income'
          : 'expense';
      final date = end.subtract(
        Duration(seconds: (index * spanSeconds) ~/ uzsDatasetSize + 1800),
      );
      final timestamp = date.toIso8601String();
      _instants[timestamp] = date.microsecondsSinceEpoch;
      result.add({
        'id': 'txn-uzs-${(uzsDatasetSize - index).toString().padLeft(4, '0')}',
        // 15 000 – 900 000 sum, whole sums as people pay them.
        'amountMinor': (15000 + uzs.nextInt(885001)) ~/ 1000 * 1000 * 100,
        'currency': 'UZS',
        'occurredAt': timestamp,
        'categoryId': category,
        'merchantId': 'uzs-$category-$merchantIndex',
        'accountId': 'uzs',
        'kind': kind,
        'status': index % 89 == 0 ? 'pending' : 'posted',
      });
    }
    result.sort(_newestFirst);
    _snapshots[1] = List.unmodifiable(result);
    if (restoreSavedState) {
      final saved = await loadState?.call();
      if (saved != null) _restore(saved);
    }
  }

  int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final date = _instant(
      b['occurredAt'] as String,
    ).compareTo(_instant(a['occurredAt'] as String));
    return date != 0 ? date : (b['id'] as String).compareTo(a['id'] as String);
  }

  /// The language of the request being handled.
  String get _language => Zone.current[_languageKey] as String? ?? 'ru';

  String _t(String key, [Map<String, Object?> args = const {}]) =>
      DemoTexts.text(_language, key, args);

  /// Handles [request] in its negotiated language. State never depends on
  /// the language; only the texts of the response do.
  Future<SimulatedResponse> handle(SimulatedRequest request) => runZoned(
    () => _handle(request),
    zoneValues: {_languageKey: request.language},
  );

  Future<SimulatedResponse> _handle(SimulatedRequest request) async {
    await _ensureData();
    await _persistence;
    try {
      for (final route in routes) {
        final custom = await route(request);
        if (custom != null) return custom;
      }
      final accountResponse = await _accountRoute(request);
      if (accountResponse != null) return accountResponse;
      final response = switch ((request.method, request.path)) {
        ('GET', '/health') => SimulatedResponse({
          'status': 'ok',
          'revision': revision,
          'datasetSize': datasetSize,
        }),
        ('GET', '/accounts') => _accounts(),
        ('GET', '/transactions') => _transactions(request.query),
        ('GET', '/analytics') => _analytics(request.query),
        ('POST', '/demo/activity') => _demoActivity(request.body),
        ('GET', '/services') => SimulatedResponse({
          'items': [
            for (final id in const ['utilities', 'mobile', 'cinema', 'fines'])
              {'id': id, 'title': _t('service.$id')},
          ],
        }),
        ('GET', '/services/fines') => _bills(
          'fines',
          request.query['document'],
        ),
        ('GET', '/services/utilities') => _bills(
          'utilities',
          request.query['account'],
        ),
        ('GET', '/services/operators') => _operators(request.query['phone']),
        ('GET', '/services/movies') => _movies(),
        ('GET', '/services/sessions') => _sessions(request.query['movieId']),
        ('GET', '/services/seats') => _seats(request.query['sessionId']),
        ('POST', '/checkout/quotes') => _quote(request.body),
        ('POST', '/checkout/payments') => _pay(request.body),
        ('GET', '/checkout/payments/status') => SimulatedResponse(
          switch (_payments[request.query['idempotencyKey']]) {
            final payment? => _publicPayment(payment),
            null => const {'status': 'not_found'},
          },
        ),
        _ => _error(404, 'not_found', 'error.notFound'),
      };
      if (request.method == 'POST' && response.statusCode == 200) {
        await _persist();
      }
      return response;
    } on _ApiProblem catch (error) {
      return _error(error.status, error.code, error.message);
    } on FormatException {
      return _error(400, 'validation', 'error.badFormat');
    }
  }

  SimulatedResponse _accounts() {
    int spent(String account) => _payments.values
        .where(
          (payment) =>
              payment['status'] == 'succeeded' &&
              (payment['_quote'] as Map<String, dynamic>)['_accountId'] ==
                  account,
        )
        .fold<int>(
          0,
          (sum, payment) =>
              sum +
              (payment['amountMinor'] as int) +
              (payment['feeMinor'] as int),
        );
    // A name the customer chose is kept as typed; default names follow the
    // request language.
    String name(String id) =>
        _accountPreferences[id]?['name'] as String? ?? _t('account.$id');
    final accounts = <Map<String, dynamic>>[
      {
        'id': 'main',
        'name': name('main'),
        'balanceMinor':
            28476580 - spent('main') + (_accountAdjustments['main'] ?? 0),
        'currency': 'RUB',
        'lastDigits': '4821',
        'kind': 'debit',
      },
      {
        'id': 'savings',
        'name': name('savings'),
        'balanceMinor':
            125000000 -
            spent('savings') +
            (_accountAdjustments['savings'] ?? 0),
        'currency': 'RUB',
        'lastDigits': '0924',
        'kind': 'savings',
      },
      for (final extra in [
        ('usd', 'USD', '3518', 150025),
        ('gbp', 'GBP', '6012', 0),
        ('business', 'RUB', '4258', 0),
        // 12 750 000 sum: an Uzbek sum account with its own ledger.
        ('uzs', 'UZS', '2207', 1275000000),
      ])
        {
          'id': extra.$1,
          'name': name(extra.$1),
          'balanceMinor':
              extra.$4 - spent(extra.$1) + (_accountAdjustments[extra.$1] ?? 0),
          'currency': extra.$2,
          'lastDigits': extra.$3,
          'kind': 'debit',
        },
    ];
    for (final account in accounts) {
      account['availableMinor'] =
          (account['balanceMinor'] as int) -
          _pendingHold(account['id'] as String);
    }
    return SimulatedResponse({'accounts': accounts, 'revision': revision});
  }

  SimulatedResponse _demoActivity(Map<String, dynamic> body) {
    final id = 'txn-live-${++_demoSequence}';
    addTransaction({
      'id': id,
      '_subtitleKey': 'entry.new',
      'amountMinor': 38500,
      'currency': 'RUB',
      'occurredAt': _ledgerTime().toIso8601String(),
      'categoryId': 'dining',
      'merchantId': 'dining-0',
      'accountId': 'main',
      'kind': 'expense',
      'status': 'posted',
    });
    String? changed;
    if (body['changeStatus'] != false) {
      // The demo event changes a rouble row, the ledger shown on the home
      // screen.
      final pending = _snapshots[_revision]!.where(
        (item) => item['status'] == 'pending' && item['currency'] == 'RUB',
      );
      if (pending.isNotEmpty) {
        final item = pending.first;
        changed = item['id'] as String;
        addTransaction({...item, 'status': 'posted'});
      }
    }
    final removeId = body['removeId'];
    final removed = removeId is String && removeTransaction(removeId);
    return SimulatedResponse({
      'revision': revision,
      'addedId': id,
      'updatedId': changed,
      if (removed) 'removedId': removeId,
    });
  }

  _Selection _select(Map<String, String> query, {bool analytics = false}) {
    final requestedRevision =
        int.tryParse(query['revision'] ?? '') ?? _revision;
    final items = _snapshots[requestedRevision];
    if (items == null) {
      throw const _ApiProblem(409, 'snapshot_expired', 'error.snapshotExpired');
    }
    final from = _boundary(query['from']);
    final to = _boundary(query['to'], end: true);
    final fromUs = from?.microsecondsSinceEpoch;
    final toUs = to?.microsecondsSinceEpoch;
    if (from != null && to != null && !from.isBefore(to)) {
      throw const _ApiProblem(400, 'validation', 'error.periodOrder');
    }
    final accounts = query['accounts']?.split(',').toSet();
    final currency = query['currency'] ?? 'RUB';
    final kind = query['kind'];
    final list = items
        .where((item) {
          final instant = _instant(item['occurredAt'] as String);
          return (fromUs == null || instant >= fromUs) &&
              (toUs == null || instant < toUs) &&
              (accounts == null || accounts.contains(item['accountId'])) &&
              (query['category'] == null ||
                  query['category'] == item['categoryId']) &&
              (query['merchant'] == null ||
                  query['merchant'] == item['merchantId']) &&
              item['currency'] == currency &&
              (analytics || kind == null || item['kind'] == kind) &&
              (analytics || kind != 'expense' || item['status'] == 'posted') &&
              (query['status'] == null || query['status'] == item['status']);
        })
        .toList(growable: false);
    return _Selection(list, requestedRevision, from, to, currency);
  }

  SimulatedResponse _transactions(Map<String, String> originalQuery) {
    final query = Map<String, String>.of(originalQuery);
    final rawLimit = int.tryParse(query['limit'] ?? '30');
    if (rawLimit == null || rawLimit < 1 || rawLimit > 100) {
      throw const _ApiProblem(400, 'validation', 'error.pageSize');
    }
    final limit = rawLimit;
    var offset = 0;
    final cursor = query['cursor'];
    final anchor = query['anchor'];
    final at = query['at'];
    if ([cursor, anchor, at].whereType<String>().length > 1) {
      throw const _ApiProblem(400, 'validation', 'error.oneContinuation');
    }
    if ((anchor != null || at != null) && query['revision'] == null) {
      throw const _ApiProblem(
        400,
        'revision_required',
        'error.revisionRequired',
      );
    }
    if (cursor != null) {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(cursor)));
      if (decoded is! Map<String, dynamic> ||
          decoded['offset'] is! int ||
          decoded['revision'] is! int ||
          decoded['filter'] != _filterKey(query)) {
        throw const _ApiProblem(400, 'invalid_cursor', 'error.invalidCursor');
      }
      offset = decoded['offset'] as int;
      final revision = decoded['revision'] as int;
      if (query['revision'] != null && query['revision'] != '$revision') {
        throw const _ApiProblem(
          409,
          'revision_mismatch',
          'error.revisionMismatch',
        );
      }
      query['revision'] = '$revision';
    }
    final selected = _select(query);
    var anchorFound = true;
    if (anchor != null) {
      final index = selected.items.indexWhere((item) => item['id'] == anchor);
      anchorFound = index >= 0;
      final near = int.tryParse(query['near'] ?? '0');
      if (near == null) {
        throw const _ApiProblem(400, 'validation', 'error.invalidNear');
      }
      final position = index >= 0
          ? index
          : near.clamp(0, max(0, selected.items.length - 1));
      offset = (position ~/ limit) * limit;
    } else if (at != null) {
      final parsed = int.tryParse(at);
      if (parsed == null || parsed < 0) {
        throw const _ApiProblem(400, 'validation', 'error.invalidAt');
      }
      offset = (parsed ~/ limit) * limit;
    }
    if (offset < 0 || offset > selected.items.length) {
      throw const _ApiProblem(400, 'invalid_cursor', 'error.cursorRange');
    }
    final end = min(offset + limit, selected.items.length);
    String cursorAt(int position) => base64Url.encode(
      utf8.encode(
        jsonEncode({
          'offset': position,
          'revision': selected.revision,
          'filter': _filterKey(query),
        }),
      ),
    );
    final next = end < selected.items.length ? cursorAt(end) : null;
    return SimulatedResponse({
      'items': [
        for (final item in selected.items.sublist(offset, end))
          _entryJson(item),
      ],
      'nextCursor': next,
      'prevCursor': offset > 0 ? cursorAt(max(0, offset - limit)) : null,
      'startCursor': cursorAt(offset),
      'startIndex': offset,
      if (anchor != null) 'anchorFound': anchorFound,
      'total': selected.items.length,
      'totalMinor': _sumExpenses(selected.items),
      'revision': '${selected.revision}',
      'currency': selected.currency,
      'timezone': reportTimezone,
    });
  }

  String _filterKey(Map<String, String> query) {
    final keys =
        query.keys
            .where(
              (key) => !const {
                'cursor',
                'revision',
                'limit',
                'anchor',
                'near',
                'at',
              }.contains(key),
            )
            .toList()
          ..sort();
    return jsonEncode({for (final key in keys) key: query[key]});
  }

  SimulatedResponse _analytics(Map<String, String> query) {
    final selected = _select(query, analytics: true);
    final expenses = selected.items
        .where(
          (item) => item['kind'] == 'expense' && item['status'] == 'posted',
        )
        .toList(growable: false);
    final from = selected.from ?? DateTime.utc(2025, 10, 16, 21);
    final to = selected.to ?? DateTime.utc(2026, 10, 16, 21);
    final comparisonTo = from;
    final comparisonFrom = from.subtract(to.difference(from));
    final comparisonQuery = {
      ...query,
      'from': comparisonFrom.toIso8601String(),
      'to': comparisonTo.toIso8601String(),
      'revision': '${selected.revision}',
    };
    final previous = _select(comparisonQuery, analytics: true);
    final refunds = selected.items.where(
      (item) => item['kind'] == 'refund' && item['status'] == 'posted',
    );
    final categoryGroups = <String, _Aggregate>{};
    final merchantGroups = <String, _Aggregate>{};
    for (final item in expenses) {
      final category = item['categoryId'] as String;
      final merchant = item['merchantId'] as String;
      (categoryGroups[category] ??= _Aggregate(
        category,
        _categoryName(category),
      )).add(item['amountMinor'] as int);
      (merchantGroups[merchant] ??= _Aggregate(
        merchant,
        _entryTitle(item),
      )).add(item['amountMinor'] as int);
    }
    List<Map<String, dynamic>> ranked(Map<String, _Aggregate> groups) =>
        (groups.values.toList()..sort((a, b) => b.amount.compareTo(a.amount)))
            .map((entry) => entry.toJson())
            .toList(growable: false);
    final timeline = _timeline(from, to, expenses);
    return SimulatedResponse({
      'totalMinor': _sumExpenses(expenses),
      'refundMinor': refunds.fold<int>(
        0,
        (sum, item) => sum + (item['amountMinor'] as int),
      ),
      'previousTotalMinor': _sumExpenses(previous.items),
      'comparisonFrom': comparisonFrom.toIso8601String(),
      'comparisonTo': comparisonTo.toIso8601String(),
      'comparisonHasData': previous.items.isNotEmpty,
      'count': expenses.length,
      'revision': '${selected.revision}',
      'currency': selected.currency,
      'timezone': reportTimezone,
      'categories': ranked(categoryGroups),
      'merchants': ranked(merchantGroups),
      'timeline': timeline,
      'metricRule': _t('analytics.metricRule'),
    });
  }

  List<Map<String, dynamic>> _timeline(
    DateTime from,
    DateTime to,
    List<Map<String, dynamic>> expenses,
  ) {
    final days = to.difference(from).inDays;
    final months = days > 90;
    final step = Duration(days: days > 35 ? 7 : 1);
    var at = from;
    final result = <Map<String, dynamic>>[];
    while (at.isBefore(to)) {
      final local = at.add(const Duration(hours: 3));
      final proposed = months
          ? DateTime.utc(
              local.year,
              local.month + 1,
              1,
            ).subtract(const Duration(hours: 3))
          : at.add(step);
      final next = proposed.isAfter(to) ? to : proposed;
      result.add({
        'id': at.toIso8601String(),
        'label': months
            ? '${local.month.toString().padLeft(2, '0')}.${local.year}'
            : '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}',
        'from': at.toIso8601String(),
        'to': next.toIso8601String(),
        'amountMinor': 0,
        'count': 0,
      });
      at = next;
    }
    final boundaries = result
        .map((bucket) => _instant(bucket['from'] as String))
        .toList(growable: false);
    for (final expense in expenses) {
      final instant = _instant(expense['occurredAt'] as String);
      var low = 0;
      var high = boundaries.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if (boundaries[middle] > instant) {
          high = middle;
        } else {
          low = middle + 1;
        }
      }
      if (low == 0 || instant >= to.microsecondsSinceEpoch) continue;
      final bucket = result[low - 1];
      bucket['amountMinor'] =
          (bucket['amountMinor'] as int) + (expense['amountMinor'] as int);
      bucket['count'] = (bucket['count'] as int) + 1;
    }
    return result;
  }

  String _categoryName(String id) => DemoTexts.has('category.$id')
      ? _t('category.$id')
      : _t('category.unknown');

  /// A ledger row as sent to the client: internal fields removed, title and
  /// subtitle named in the request language.
  Map<String, dynamic> _entryJson(Map<String, dynamic> item) => {
    ..._public(item),
    'title': _entryTitle(item),
    'subtitle': _entrySubtitle(item),
  };

  /// In order: a payment's recipient, a stored text key, a title given by a
  /// scenario hook (or an older saved state), or the generated merchant.
  String _entryTitle(Map<String, dynamic> item) {
    if (item['_recipient'] case final Map<dynamic, dynamic> recipient) {
      return _recipientName(
        recipient['kind'] as String,
        Map<String, dynamic>.from(recipient['details'] as Map? ?? const {}),
      );
    }
    if (item['_titleKey'] case final String key) return _t(key);
    if (item['title'] case final String title) return title;
    final merchant = 'merchant.${item['merchantId']}';
    return switch (item['kind']) {
      'income' => _t('entry.topUp'),
      'transfer' => _t('entry.ownTransfer'),
      _ when DemoTexts.has(merchant) => _t(merchant),
      _ => '${item['merchantId']}',
    };
  }

  String _entrySubtitle(Map<String, dynamic> item) {
    if (item['_subtitleKey'] case final String key) return _t(key);
    if (item['subtitle'] case final String subtitle) return subtitle;
    return item['kind'] == 'refund'
        ? _t('entry.refund')
        : _categoryName(item['categoryId'] as String);
  }

  /// The payee of a service payment, named by the server whatever reference
  /// the client sent.
  String _recipientName(String kind, Map<String, dynamic> details) =>
      switch (kind) {
        'mobile' => _t('operator.${details['operatorId']}'),
        'fines' => _t('recipient.fines'),
        'utilities' => _t('recipient.utilities'),
        'cinema' => _t('cinema.recipient', {
          'movie': _t(
            'movie.${_movieOf(details['sessionId'] as String?)}.title',
          ),
        }),
        _ => kind,
      };

  /// `movie-001-evening` → `movie-001`.
  static String _movieOf(String? session) =>
      (session ?? '').replaceFirst(RegExp(r'-(evening|night)$'), '');

  int _sumExpenses(Iterable<Map<String, dynamic>> items) => items
      .where((item) => item['kind'] == 'expense' && item['status'] == 'posted')
      .fold<int>(0, (sum, item) => sum + (item['amountMinor'] as int));

  int _instant(String timestamp) =>
      _instants[timestamp] ??= DateTime.parse(timestamp).microsecondsSinceEpoch;

  DateTime? _boundary(String? raw, {bool end = false}) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.contains('T')) {
      final local = DateTime.parse('${raw}T00:00:00+03:00').toUtc();
      return end ? local.add(const Duration(days: 1)) : local;
    }
    return DateTime.parse(raw).toUtc();
  }

  SimulatedResponse _bills(String kind, String? identifier) {
    if (identifier == null || identifier.trim().length < 5) {
      return _error(422, 'validation', 'error.document');
    }
    if (identifier.endsWith('00000')) {
      return const SimulatedResponse({'items': <Object>[]});
    }
    final bills = _allBills(kind)
        .map((bill) {
          final paid = _paidBills.contains(bill['id']);
          return {...bill, 'paid': paid, 'version': paid ? '2' : '1'};
        })
        .toList(growable: false);
    return SimulatedResponse({'items': bills});
  }

  List<Map<String, dynamic>> _allBills(String kind) {
    Map<String, dynamic> bill(
      String id,
      int amountMinor,
      String dueDate, {
      bool provider = false,
    }) => {
      'id': id,
      'title': _t('bill.$id.title'),
      'description': _t('bill.$id.description'),
      if (provider) 'provider': _t('bill.$id.provider'),
      'amountMinor': amountMinor,
      'currency': 'RUB',
      'dueDate': dueDate,
    };
    return kind == 'fines'
        ? [
            bill('fine-001', 75000, '2026-11-10T21:00:00.000Z'),
            bill('fine-002', 150000, '2026-11-15T21:00:00.000Z'),
          ]
        : [
            bill(
              'utility-001',
              684320,
              '2026-11-10T21:00:00.000Z',
              provider: true,
            ),
            bill(
              'utility-002',
              125670,
              '2026-11-10T21:00:00.000Z',
              provider: true,
            ),
          ];
  }

  SimulatedResponse _operators(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      return _error(422, 'validation', 'error.phoneDigits');
    }
    return SimulatedResponse({
      'items': [
        for (final id in const ['mts', 'megafon', 'beeline', 't2'])
          {'id': id, 'name': _t('operator.$id')},
      ],
      'suggestedId': 'mts',
    });
  }

  SimulatedResponse _movies() => SimulatedResponse({
    'items': [
      for (final (id, minutes) in const [
        ('movie-001', 118),
        ('movie-002', 102),
      ])
        {
          'id': id,
          'title': _t('movie.$id.title'),
          'description': _t('movie.$id.description'),
          'durationMinutes': minutes,
        },
    ],
  });

  SimulatedResponse _sessions(String? movie) {
    if (!const ['movie-001', 'movie-002'].contains(movie)) {
      return _error(404, 'not_found', 'error.movieNotFound');
    }
    return SimulatedResponse({
      'items': [
        {
          'id': '$movie-evening',
          'movieId': movie,
          'startsAt': '2026-10-17T16:00:00.000Z',
          'cinema': _t('cinema.hall', {'hall': 2}),
          'priceMinor': 65000,
          'currency': 'RUB',
        },
        {
          'id': '$movie-night',
          'movieId': movie,
          'startsAt': '2026-10-17T18:30:00.000Z',
          'cinema': _t('cinema.hall', {'hall': 1}),
          'priceMinor': 75000,
          'currency': 'RUB',
        },
      ],
    });
  }

  bool _validSession(String? id) => const [
    'movie-001-evening',
    'movie-001-night',
    'movie-002-evening',
    'movie-002-night',
  ].contains(id);

  SimulatedResponse _seats(String? session) {
    if (!_validSession(session)) {
      return _error(404, 'not_found', 'error.sessionNotFound');
    }
    return SimulatedResponse({
      'version': '$_seatRevision',
      'items': List.generate(24, (index) {
        final id = 'seat-${index + 1}';
        return {
          'id': id,
          'label': _t('cinema.seat', {
            'row': index ~/ 6 + 1,
            'seat': index % 6 + 1,
          }),
          'available':
              !const [1, 8, 14].contains(index) &&
              !_reservedSeats.contains('$session/$id'),
          'priceMinor': session!.endsWith('night') ? 75000 : 65000,
          'currency': 'RUB',
        };
      }),
    });
  }

  SimulatedResponse _quote(Map<String, dynamic> body) {
    final kind = body['kind'];
    final account = body['accountId'];
    if (!const ['fines', 'utilities', 'mobile', 'cinema'].contains(kind) ||
        (account is! String || _findAccount(account)?['currency'] != 'RUB') ||
        body['currency'] != 'RUB' ||
        (body['recipient'] as String? ?? '').trim().isEmpty) {
      return _error(422, 'validation', 'error.paymentDetails');
    }
    final details = body['details'] is Map
        ? Map<String, dynamic>.from(body['details'] as Map)
        : <String, dynamic>{};
    final references = body['referenceIds'] is List
        ? (body['referenceIds'] as List).cast<String>()
        : <String>[];
    if (references.toSet().length != references.length) {
      return _error(422, 'validation', 'error.duplicateBill');
    }
    var amount = 0;
    switch (kind) {
      case 'mobile':
        final digits = (details['phone'] as String? ?? '').replaceAll(
          RegExp(r'\D'),
          '',
        );
        final requested = body['amountMinor'];
        if (digits.length != 11 ||
            !const [
              'mts',
              'megafon',
              'beeline',
              't2',
            ].contains(details['operatorId']) ||
            requested is! int ||
            requested < 10000 ||
            requested > 1500000) {
          return _error(422, 'validation', 'error.mobileAmount');
        }
        amount = requested;
      case 'fines' || 'utilities':
        if (references.isEmpty) {
          return _error(422, 'validation', 'error.chooseBills');
        }
        final bills = _allBills(kind as String);
        final versions = details['billVersions'] is Map
            ? Map<String, dynamic>.from(details['billVersions'] as Map)
            : <String, dynamic>{};
        for (final id in references) {
          final matching = bills.where((bill) => bill['id'] == id);
          if (matching.isEmpty) {
            return _error(422, 'validation', 'error.billNotFound');
          }
          if (_paidBills.contains(id) ||
              (versions[id] != null && versions[id] != '1')) {
            return _error(409, 'bill_stale', 'error.billChanged');
          }
          amount += matching.single['amountMinor'] as int;
        }
      case 'cinema':
        final conflict = _checkSeats(references, details);
        if (conflict != null) return conflict;
        amount =
            references.length *
            ((details['sessionId'] as String).endsWith('night')
                ? 75000
                : 65000);
    }
    if (_spendable(account) < amount + (kind == 'utilities' ? 1000 : 0)) {
      return _error(422, 'insufficient_funds', 'error.insufficientFunds');
    }
    final quote = <String, dynamic>{
      'id': 'quote-${++_quoteSequence}',
      'amountMinor': amount,
      'feeMinor': kind == 'utilities' ? 1000 : 0,
      'currency': 'RUB',
      'expiresAt': _now().add(const Duration(minutes: 5)).toIso8601String(),
      // The client's recipient is only a reference; the server names the
      // payee and the purpose in the language of each response.
      '_recipientRef': body['recipient'],
      '_kind': kind,
      '_referenceIds': references,
      '_details': details,
      '_accountId': account,
    };
    _pruneQuotes();
    _quotes[quote['id'] as String] = quote;
    return SimulatedResponse(_publicQuote(quote));
  }

  Map<String, dynamic> _publicQuote(Map<String, dynamic> quote) {
    final kind = quote['_kind'] as String;
    return {
      ..._public(quote),
      'recipient': _recipientName(
        kind,
        Map<String, dynamic>.from(quote['_details'] as Map? ?? const {}),
      ),
      'description': _t('purpose.$kind'),
    };
  }

  /// Ticket and failure texts are built at response time, so a receipt reads
  /// in the language of whoever asks for it.
  Map<String, dynamic> _publicPayment(Map<String, dynamic> payment) {
    final quote = payment['_quote'] as Map<String, dynamic>;
    final ticket = payment['_ticket'];
    return {
      ..._public(payment),
      'description': _t('purpose.${quote['_kind']}'),
      if (ticket is Map)
        'ticket': _t('cinema.ticket', {
          'session': ticket['session'],
          'seats': (ticket['seats'] as List).join(', '),
          'id': payment['id'],
        }),
      if (payment['status'] == 'failed') 'failureMessage': _t('error.declined'),
    };
  }

  /// Expired quotes stay for an hour so a late confirmation still receives an
  /// explicit `quote_expired`; older ones are dropped to keep the persisted
  /// state bounded. A payment keeps its own copy of the quote it consumed.
  void _pruneQuotes() {
    final cutoff = _now().subtract(const Duration(hours: 1));
    _quotes.removeWhere(
      (_, quote) =>
          DateTime.parse(quote['expiresAt'] as String).isBefore(cutoff),
    );
  }

  SimulatedResponse? _checkSeats(
    List<String> references,
    Map<String, dynamic> details,
  ) {
    final session = details['sessionId'] as String?;
    if (!_validSession(session) || references.isEmpty) {
      return _error(422, 'validation', 'error.chooseSeats');
    }
    if (details['seatVersion'] != '$_seatRevision') {
      return _error(409, 'seat_conflict', 'error.seatsChanged');
    }
    final items = _seats(session).body['items'] as List;
    for (final id in references) {
      final matching = items.where((item) => (item as Map)['id'] == id);
      if (matching.isEmpty || (matching.single as Map)['available'] != true) {
        return _error(409, 'seat_conflict', 'error.seatTaken');
      }
    }
    return null;
  }

  SimulatedResponse _pay(Map<String, dynamic> body) {
    final key = body['idempotencyKey'];
    final quoteId = body['quoteId'];
    if (key is! String || key.length < 8 || quoteId is! String) {
      return _error(422, 'validation', 'error.missingKey');
    }
    final existing = _payments[key];
    if (existing != null) {
      return existing['quoteId'] == quoteId
          ? SimulatedResponse(_publicPayment(existing))
          : _error(409, 'idempotency_conflict', 'error.keyUsed');
    }
    final quote = _quotes[quoteId];
    if (quote == null) return _error(404, 'not_found', 'error.quoteNotFound');
    if (!_now().isBefore(DateTime.parse(quote['expiresAt'] as String))) {
      return _error(409, 'quote_expired', 'error.quoteExpired');
    }
    if (_spendable(quote['_accountId'] as String) <
        (quote['amountMinor'] as int) + (quote['feeMinor'] as int)) {
      return _error(422, 'insufficient_funds', 'error.insufficientFunds');
    }
    final kind = quote['_kind'] as String;
    final references = (quote['_referenceIds'] as List).cast<String>();
    final pendingQuotes = _payments.values
        .where((payment) => payment['status'] == 'pending')
        .map((payment) => payment['_quote'] as Map<String, dynamic>);
    for (final pending in pendingQuotes) {
      final pendingReferences = (pending['_referenceIds'] as List)
          .cast<String>();
      if (references.any(pendingReferences.contains) &&
          kind == pending['_kind'] &&
          (kind != 'cinema' ||
              (quote['_details'] as Map)['sessionId'] ==
                  (pending['_details'] as Map)['sessionId'])) {
        return _error(409, 'payment_pending', 'error.billProcessing');
      }
    }
    if (kind == 'cinema') {
      final conflict = _checkSeats(
        references,
        quote['_details'] as Map<String, dynamic>,
      );
      if (conflict != null) return conflict;
    } else if (references.any(_paidBills.contains)) {
      return _error(409, 'bill_stale', 'error.billPaid');
    }
    final payment = <String, dynamic>{
      'id': 'payment-${++_paymentSequence}',
      'idempotencyKey': key,
      'quoteId': quoteId,
      'status': pendingNextPayment ? 'pending' : 'succeeded',
      'amountMinor': quote['amountMinor'],
      'feeMinor': quote['feeMinor'],
      'currency': quote['currency'],
      'createdAt': _now().toIso8601String(),
      '_quote': quote,
    };
    pendingNextPayment = false;
    _payments[key] = payment;
    if (payment['status'] == 'succeeded') _completePayment(payment);
    return SimulatedResponse(_publicPayment(payment));
  }

  Future<void> settlePendingPayments({bool succeeded = true}) async {
    for (final payment in _payments.values) {
      if (payment['status'] != 'pending') continue;
      payment['status'] = succeeded ? 'succeeded' : 'failed';
      if (succeeded) _completePayment(payment);
    }
    await _persist();
  }

  void _completePayment(Map<String, dynamic> payment) {
    final quote = payment['_quote'] as Map<String, dynamic>;
    final kind = quote['_kind'] as String;
    final references = (quote['_referenceIds'] as List).cast<String>();
    payment['receiptId'] = 'receipt-${payment['id']}';
    if (kind == 'cinema') {
      final details = quote['_details'] as Map<String, dynamic>;
      for (final id in references) {
        _reservedSeats.add('${details['sessionId']}/$id');
      }
      _seatRevision++;
      payment['_ticket'] = {
        'session': details['sessionId'],
        'seats': references,
      };
    } else if (kind != 'mobile') {
      _paidBills.addAll(references);
    }
    final category = switch (kind) {
      'utilities' || 'mobile' => 'utilities',
      'cinema' => 'entertainment',
      _ => 'other',
    };
    addTransaction({
      'id': 'txn-${payment['id']}',
      '_recipient': {'kind': kind, 'details': quote['_details']},
      '_subtitleKey': 'purpose.$kind',
      'amountMinor': (quote['amountMinor'] as int) + (quote['feeMinor'] as int),
      'currency': quote['currency'],
      'occurredAt': _ledgerTime().toIso8601String(),
      'categoryId': category,
      'merchantId': 'provider-$kind',
      'accountId': quote['_accountId'],
      'kind': 'expense',
      'status': 'posted',
    });
  }

  /// Scenario hook used for new operations and status changes while reading.
  /// Snapshots keep existing cursors consistent when the live revision changes.
  void addTransaction(Map<String, dynamic> item) {
    if (_snapshots.isEmpty) {
      throw StateError('Await first request before mutation');
    }
    if (item['amountMinor'] is! int || (item['amountMinor'] as int) <= 0) {
      throw ArgumentError.value(item['amountMinor'], 'amountMinor');
    }
    _mutations[item['id'] as String] = Map<String, dynamic>.of(item);
    final next =
        [
          ..._snapshots[_revision]!.where((old) => old['id'] != item['id']),
          Map<String, dynamic>.unmodifiable(item),
        ]..sort((a, b) {
          final date = _instant(
            b['occurredAt'] as String,
          ).compareTo(_instant(a['occurredAt'] as String));
          return date != 0
              ? date
              : (b['id'] as String).compareTo(a['id'] as String);
        });
    _snapshots[++_revision] = List.unmodifiable(next);
    while (_snapshots.length > 12) {
      _snapshots.remove(_snapshots.keys.first);
    }
  }

  bool removeTransaction(String id) {
    final current = _snapshots[_revision];
    if (current == null) {
      throw StateError('Await first request before mutation');
    }
    if (!current.any((item) => item['id'] == id)) return false;
    _mutations[id] = {'id': id, '_removed': true};
    _snapshots[++_revision] = List.unmodifiable(
      current.where((item) => item['id'] != id),
    );
    while (_snapshots.length > 12) {
      _snapshots.remove(_snapshots.keys.first);
    }
    return true;
  }

  Map<String, dynamic> exportState() => Map<String, dynamic>.from(
    jsonDecode(
          jsonEncode({
            'schema': 1,
            'revision': _revision,
            'quotes': _quotes,
            'payments': _payments,
            'paidBills': _paidBills.toList(growable: false),
            'reservedSeats': _reservedSeats.toList(growable: false),
            'seatRevision': _seatRevision,
            'quoteSequence': _quoteSequence,
            'paymentSequence': _paymentSequence,
            'demoSequence': _demoSequence,
            'ledgerSequence': _ledgerSequence,
            'mutations': _mutations,
            'accountAdjustments': _accountAdjustments,
            'accountPreferences': _accountPreferences,
            'accountOperations': _accountOperations,
          }),
        )
        as Map,
  );

  Future<void> restoreState(Map<String, dynamic> state) async {
    await _ensureData();
    await _persistence;
    _restore(state);
  }

  void _restore(Map<String, dynamic> state) {
    if (state['schema'] != 1) throw const FormatException('Unknown demo state');
    void restoreMaps(Map<String, Map<String, dynamic>> target, String name) {
      target.clear();
      final values = state[name] as Map;
      for (final entry in values.entries) {
        target[entry.key as String] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
    }

    restoreMaps(_quotes, 'quotes');
    restoreMaps(_payments, 'payments');
    restoreMaps(_mutations, 'mutations');
    _accountAdjustments
      ..clear()
      ..addAll(
        Map<String, int>.from(state['accountAdjustments'] as Map? ?? {}),
      );
    for (final pair in [
      (_accountPreferences, 'accountPreferences'),
      (_accountOperations, 'accountOperations'),
    ]) {
      pair.$1.clear();
      for (final entry in (state[pair.$2] as Map? ?? {}).entries) {
        pair.$1[entry.key as String] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
    }
    _paidBills
      ..clear()
      ..addAll((state['paidBills'] as List).cast<String>());
    _reservedSeats
      ..clear()
      ..addAll((state['reservedSeats'] as List).cast<String>());
    _seatRevision = state['seatRevision'] as int;
    _quoteSequence = state['quoteSequence'] as int;
    _paymentSequence = state['paymentSequence'] as int;
    _demoSequence = state['demoSequence'] as int;
    _ledgerSequence = state['ledgerSequence'] as int? ?? 0;
    _revision = state['revision'] as int;
    if (_mutations.isNotEmpty) {
      final restored =
          [
            ..._snapshots[1]!.where(
              (item) => !_mutations.containsKey(item['id']),
            ),
            ..._mutations.values.where((item) => item['_removed'] != true),
          ]..sort((a, b) {
            final date = DateTime.parse(
              b['occurredAt'] as String,
            ).compareTo(DateTime.parse(a['occurredAt'] as String));
            return date != 0
                ? date
                : (b['id'] as String).compareTo(a['id'] as String);
          });
      _snapshots[_revision] = List.unmodifiable(restored);
    }
  }

  Future<void> _persist() {
    final save = saveState;
    if (save == null) return Future<void>.value();
    final snapshot = exportState();
    final saved = _persistence.then((_) => save(snapshot));
    // A failed save fails only the request that caused it. Keeping the error
    // in the chain would make every later mutation fail without being tried.
    _persistence = saved.catchError((Object _) {});
    return saved;
  }

  Map<String, dynamic> _public(Map<String, dynamic> body) => {
    for (final entry in body.entries)
      if (!entry.key.startsWith('_')) entry.key: entry.value,
  };

  /// [messageKey] names a [DemoTexts] entry; the message is sent in the
  /// request language.
  SimulatedResponse _error(int status, String code, String messageKey) {
    final message = _t(messageKey);
    return SimulatedResponse({
      'error': {'code': code, 'message': message},
      'code': code,
      'message': message,
    }, statusCode: status);
  }
}

final class _Selection {
  const _Selection(
    this.items,
    this.revision,
    this.from,
    this.to,
    this.currency,
  );

  final List<Map<String, dynamic>> items;
  final int revision;
  final DateTime? from;
  final DateTime? to;
  final String currency;
}

final class _Aggregate {
  _Aggregate(this.id, this.label);

  final String id;
  final String label;
  int amount = 0;
  int count = 0;

  void add(int value) {
    amount += value;
    count++;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'amountMinor': amount,
    'count': count,
  };
}

final class _ApiProblem implements Exception {
  const _ApiProblem(this.status, this.code, this.message);

  final int status;
  final String code;

  /// A [DemoTexts] key.
  final String message;
}
