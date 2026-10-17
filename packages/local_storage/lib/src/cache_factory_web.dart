import 'dart:js_interop';

import 'cache_store.dart';

@JS('globalThis.localStorage')
external _BrowserStorage get _localStorage;

extension type _BrowserStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

CacheStore createCacheStore({
  String? path,
  String namespace = 'responses',
  DateTime Function()? now,
  int maxEntries = 120,
  bool durable = false,
}) => _WebCacheStore(
  namespace: path ?? 'demobank-cache-v1-$namespace',
  now: now,
  maxEntries: maxEntries,
  durable: durable,
);

final class _WebCacheStore implements CacheStore {
  _WebCacheStore({
    required this.namespace,
    DateTime Function()? now,
    this.maxEntries = 120,
    this.durable = false,
  }) : _now = now ?? DateTime.now,
       _fallback = MemoryCacheStore(
         now: now,
         maxEntries: maxEntries,
         durable: durable,
       );

  final String namespace;
  final DateTime Function() _now;
  final int maxEntries;
  final bool durable;
  final MemoryCacheStore _fallback;
  bool _closed = false;

  String _key(String key) => '$namespace:$key';

  List<String> _keys() => (_localStorage.getItem('$namespace:index') ?? '')
      .split('\n')
      .where((key) => key.isNotEmpty)
      .toList();

  void _saveKeys(List<String> keys) =>
      _localStorage.setItem('$namespace:index', keys.join('\n'));

  @override
  Future<CacheEntry?> read(String key) async {
    _checkOpen();
    String? value;
    try {
      value = _localStorage.getItem(_key(key));
      if (value != null) {
        final keys = _keys()..remove(key);
        _saveKeys([...keys, key]);
      }
    } on Object {
      return _fallback.read(key);
    }
    if (value == null) return _fallback.read(key);
    try {
      return decodeEntry(value, _now);
    } on Object {
      if (durable) throw CorruptCacheEntry(key);
      await delete(key);
      return null;
    }
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) async {
    _checkOpen();
    final encoded = encodeEntry(value, _now(), ttl, revision);
    try {
      final keys = _keys()..remove(key);
      keys.add(key);
      _localStorage.setItem(_key(key), encoded);
      while (!durable && keys.length > maxEntries) {
        _localStorage.removeItem(_key(keys.removeAt(0)));
      }
      _saveKeys(keys);
    } on Object {
      // Browser storage can be disabled or full; cache failure must not prevent
      // opening a screen. The fallback is bounded and session-local.
      await _fallback.write(key, value, ttl: ttl, revision: revision);
    }
  }

  @override
  Future<void> delete(String key) async {
    _checkOpen();
    try {
      _localStorage.removeItem(_key(key));
      _saveKeys(_keys()..remove(key));
    } on Object {
      // The same storage operation may be unavailable in a private context.
    }
    await _fallback.delete(key);
  }

  @override
  Future<String?> quarantine(String key) async {
    _checkOpen();
    try {
      final raw = _localStorage.getItem(_key(key));
      if (raw != null) {
        final target = quarantineKey(key, _now());
        _localStorage.setItem(_key(target), raw);
        _localStorage.removeItem(_key(key));
        final keys = _keys()..remove(key);
        _saveKeys([...keys, target]);
        return target;
      }
    } on Object {
      // Unavailable browser storage falls back to the session-local copy.
    }
    return _fallback.quarantine(key);
  }

  @override
  Future<void> clear() async {
    _checkOpen();
    try {
      for (final key in _keys()) {
        _localStorage.removeItem(_key(key));
      }
      _localStorage.removeItem('$namespace:index');
    } on Object {
      // Session-local fallback still clears below.
    }
    await _fallback.clear();
  }

  @override
  Future<void> expireAll() async {
    _checkOpen();
    try {
      for (final key in _keys()) {
        final value = _localStorage.getItem(_key(key));
        if (value != null) {
          _localStorage.setItem(_key(key), expireEntry(value, _now()));
        }
      }
    } on Object {
      // Unavailable browser storage falls back to session-local cache.
    }
    await _fallback.expireAll();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _fallback.close();
  }

  void _checkOpen() {
    if (_closed) throw StateError('CacheStore is closed');
  }
}
