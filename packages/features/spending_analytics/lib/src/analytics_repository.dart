import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

final class ApiAnalyticsRepository implements ScopedAnalyticsReader {
  ApiAnalyticsRepository(this._api, this._cache)
    : _inFlight = {},
      _scoped = false;
  ApiAnalyticsRepository._scope(this._api, this._cache, this._inFlight)
    : _scoped = true;
  final Map<String, _AnalyticsRequest> _inFlight;
  final bool _scoped;
  _AnalyticsRequest? _pending;

  @override
  ApiAnalyticsRepository createScope() =>
      ApiAnalyticsRepository._scope(_api, _cache, _inFlight);

  /// A data change starts a new generation without cancelling other consumers.
  void invalidate() {
    for (final request in _inFlight.values) {
      request.retired = true;
    }
    _inFlight.clear();
  }

  @override
  void cancelPending() {
    final request = _pending;
    _pending = null;
    if (request == null) return;
    request.users--;
    if (request.users == 0) {
      if (identical(_inFlight[request.key], request)) {
        _inFlight.remove(request.key);
      }
      if (!request.finished) request.cancellation.cancel();
    }
  }

  final ApiClient _api;
  final CacheStore _cache;
  String _key(LedgerFilter filter) => 'analytics:${filter.cacheKey}';
  @override
  Future<SpendingSummary?> cached(LedgerFilter filter) =>
      _cache.readDecoded(_key(filter), (value) => _decode(value, filter));

  @override
  Future<SpendingSummary> summary(LedgerFilter filter) async {
    if (!_scoped) return createScope().summary(filter);
    final key = '${_api.acceptLanguage}:${filter.cacheKey}';
    final shared = _inFlight[key];
    if (!identical(_pending, shared) || shared == null) cancelPending();
    final request = _inFlight.putIfAbsent(key, () {
      final request = _AnalyticsRequest(key);
      request.result = _fetch(filter, request).whenComplete(() {
        request.finished = true;
        if (identical(_inFlight[key], request)) _inFlight.remove(key);
      });
      return request;
    });
    if (!identical(_pending, request)) {
      _pending = request;
      request.users++;
    }
    try {
      return await request.result;
    } finally {
      if (identical(_pending, request)) cancelPending();
    }
  }

  Future<SpendingSummary> _fetch(
    LedgerFilter filter,
    _AnalyticsRequest request,
  ) async {
    final cache = _cache.pinned();
    final json = await _api.get(
      '/v1/analytics',
      query: filter.toQuery(),
      cancellation: request.cancellation,
    );
    final result = _decode(json, filter);
    if (!request.cancellation.isCancelled && !request.retired) {
      await cache.writeResponse(_key(filter), json, revision: result.revision);
    }
    return result;
  }

  SpendingSummary _decode(Map<String, dynamic> json, LedgerFilter filter) {
    final result = decodeSpendingSummary(json);
    if (result.total.currency != filter.currency) {
      throw const FormatException(
        'Analytics response currency differs from filter',
      );
    }
    return result;
  }
}

final class _AnalyticsRequest {
  _AnalyticsRequest(this.key);
  final String key;
  final cancellation = RequestCancellation();
  late final Future<SpendingSummary> result;
  int users = 0;
  bool finished = false;
  bool retired = false;
}
