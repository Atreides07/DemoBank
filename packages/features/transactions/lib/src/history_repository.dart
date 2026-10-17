import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

final class ApiHistoryRepository implements HistoryReader {
  ApiHistoryRepository(this._api, this._cache);
  final ApiClient _api;
  final CacheStore _cache;
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
  }) async {
    final json = await _api.get(
      '/v1/transactions',
      query: {
        ...filter.toQuery(),
        'limit': limit,
        'cursor': ?cursor,
        'at': ?startIndex,
      },
    );
    final result = _decode(json, filter);
    await _cache.write(
      _key(filter, startIndex == null ? cursor : result.startCursor),
      json,
      revision: result.revision,
    );
    return result;
  }

  @override
  Future<LedgerPage> around(
    LedgerFilter filter,
    String anchorId, {
    int fallbackIndex = 0,
  }) async {
    final json = await _api.get(
      '/v1/transactions',
      query: {
        ...filter.toQuery(),
        'anchor': anchorId,
        'near': fallbackIndex,
        'limit': 30,
      },
    );
    final result = _decode(json, filter);
    await _cache.write(
      _key(filter, result.startCursor),
      json,
      revision: result.revision,
    );
    return result;
  }

  LedgerPage _decode(Map<String, dynamic> json, LedgerFilter filter) {
    final result = decodeLedgerPage(json);
    if (result.totalAmount.currency != filter.currency) {
      throw const FormatException(
        'Ledger response currency differs from filter',
      );
    }
    return result;
  }
}
