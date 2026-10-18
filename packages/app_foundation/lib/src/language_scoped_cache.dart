import 'package:local_storage/local_storage.dart';

/// A view of a response cache in which every key belongs to one content
/// language. Server responses carry names and descriptions in the requested
/// language, so a copy cached in Russian must not be shown after switching to
/// English. Clearing and expiry apply to the whole store.
final class LanguageScopedCache implements CacheStore {
  LanguageScopedCache(this._store, this._language);

  final CacheStore _store;
  final String Function() _language;

  String _key(String key) => '${_language()}:$key';

  @override
  Future<CacheEntry?> read(String key) => _store.read(_key(key));

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) => _store.write(_key(key), value, ttl: ttl, revision: revision);

  @override
  Future<void> delete(String key) => _store.delete(_key(key));

  @override
  Future<String?> quarantine(String key) => _store.quarantine(_key(key));

  @override
  Future<void> clear() => _store.clear();

  @override
  Future<void> expireAll() => _store.expireAll();

  @override
  Future<void> close() => _store.close();
}
