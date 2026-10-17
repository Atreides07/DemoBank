import 'package:bank_core/bank_core.dart';
import 'package:ledger_data/ledger_data.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';

final class ApiAnalyticsRepository implements AnalyticsReader {
  ApiAnalyticsRepository(this._api, this._cache);
  final ApiClient _api;
  final CacheStore _cache;
  String _key(LedgerFilter filter) => 'analytics:${filter.cacheKey}';
  @override
  Future<SpendingSummary?> cached(LedgerFilter filter) async {
    final value = await _cache.read(_key(filter));
    return value == null ? null : _decode(value.value, filter);
  }

  @override
  Future<SpendingSummary> summary(LedgerFilter filter) async {
    final json = await _api.get('/v1/analytics', query: filter.toQuery());
    final result = _decode(json, filter);
    await _cache.write(_key(filter), json, revision: result.revision);
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
