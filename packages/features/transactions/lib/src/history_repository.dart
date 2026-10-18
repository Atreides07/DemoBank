import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

final class ApiHistoryRepository implements ScopedHistoryReader {
  ApiHistoryRepository(this._api, this._cache);
  final ApiClient _api;
  final CacheStore _cache;
  final _pending = <RequestCancellation>{};
  @override
  ApiHistoryRepository createScope() => ApiHistoryRepository(_api, _cache);
  @override
  void cancelPending() {
    for (final request in _pending) {
      request.cancel();
    }
    _pending.clear();
  }

  String _key(LedgerFilter filter, String? cursor) =>
      'history:${filter.cacheKey}:${cursor ?? 'first'}';
  @override
  Future<LedgerPage?> cached(LedgerFilter filter, {String? cursor}) => _cache
      .readDecoded(_key(filter, cursor), (value) => _decode(value, filter));

  @override
  Future<LedgerPage> page(
    LedgerFilter filter, {
    String? cursor,
    int limit = 30,
    int? startIndex,
  }) => _load(filter, {
    ...filter.toQuery(),
    'limit': limit,
    'cursor': ?cursor,
    'at': ?startIndex,
  });

  @override
  Future<LedgerPage> around(
    LedgerFilter filter,
    String anchorId, {
    int fallbackIndex = 0,
  }) => _load(filter, {
    ...filter.toQuery(),
    'anchor': anchorId,
    'near': fallbackIndex,
    'limit': 30,
  });

  Future<LedgerPage> _load(
    LedgerFilter filter,
    Map<String, dynamic> query,
  ) async {
    final cache = _cache.pinned();
    final cancellation = RequestCancellation();
    _pending.add(cancellation);
    try {
      final json = await _get(query, cancellation);
      final result = _decode(json, filter);
      if (!cancellation.isCancelled) {
        await cache.writeResponse(
          _key(
            filter,
            query['at'] != null || query['anchor'] != null
                ? result.startCursor
                : query['cursor'] as String?,
          ),
          json,
          revision: result.revision,
        );
      }
      return result;
    } finally {
      _pending.remove(cancellation);
    }
  }

  Future<Map<String, dynamic>> _get(
    Map<String, dynamic> query,
    RequestCancellation cancellation,
  ) async {
    try {
      return await _api.get(
        '/v1/transactions',
        query: query,
        cancellation: cancellation,
      );
    } on ApiFailure catch (error) {
      if (error.code == 'snapshot_expired') throw const LedgerSnapshotExpired();
      rethrow;
    }
  }

  LedgerPage _decode(Map<String, dynamic> json, LedgerFilter filter) {
    final result = decodeLedgerPage(json);
    if (filter.cardId != null &&
        result.items.any((e) => e.cardId != filter.cardId)) {
      throw const FormatException('Ledger response contains another card');
    }
    if (result.totalAmount.currency != filter.currency) {
      throw const FormatException(
        'Ledger response currency differs from filter',
      );
    }
    return result;
  }
}
