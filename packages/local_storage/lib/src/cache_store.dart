import 'dart:convert';

import 'cache_factory_native.dart'
    if (dart.library.js_interop) 'cache_factory_web.dart'
    as platform;

final class CacheEntry {
  CacheEntry({
    required Map<String, dynamic> value,
    required this.writtenAt,
    required this.expiresAt,
    this.revision,
    DateTime Function()? now,
  }) : value = Map.unmodifiable(value),
       _now = now ?? DateTime.now;

  final Map<String, dynamic> value;
  final DateTime writtenAt;
  final DateTime expiresAt;
  final String? revision;
  final DateTime Function() _now;

  bool get isFresh => _now().isBefore(expiresAt);
}

/// A durable entry exists but cannot be decoded. Durable stores keep the entry
/// and surface this error so the owner can make an explicit recovery decision;
/// it is a [FormatException], like any other malformed persisted data.
final class CorruptCacheEntry extends FormatException {
  CorruptCacheEntry(String key) : super('Corrupt durable cache entry', key);
}

abstract class CacheStore {
  /// A response cache by default: bounded LRU, and an undecodable entry is
  /// dropped as a miss. [durable] stores (recovery journals) never evict and
  /// never discard an entry silently: an undecodable entry raises
  /// [CorruptCacheEntry] and stays until it is explicitly deleted.
  factory CacheStore({
    String? path,
    String namespace = 'responses',
    DateTime Function()? now,
    int maxEntries = 120,
    bool durable = false,
  }) => platform.createCacheStore(
    path: path,
    namespace: namespace,
    now: now,
    maxEntries: maxEntries,
    durable: durable,
  );

  Future<CacheEntry?> read(String key);

  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  });

  Future<void> delete(String key);

  /// Moves the entry under [key], decodable or not, to a new key so it is no
  /// longer served but stays available for diagnosis. Returns the new key, or
  /// `null` when there was no entry. Use it instead of [delete] for recovery
  /// data that a person decided to set aside.
  Future<String?> quarantine(String key);

  Future<void> clear();
  Future<void> expireAll();
  Future<void> close();
}

/// Reading a cached representation is an optimization, never a prerequisite.
extension CacheStoreDecoding on CacheStore {
  /// Returns `null` for a miss. A stored value that [decode] rejects with a
  /// [FormatException] (an older app version, a partial write, a malformed
  /// response) is deleted and also reported as a miss, so a bad cache entry
  /// cannot block the network path. Any other error is a defect and surfaces.
  Future<T?> readDecoded<T>(
    String key,
    T Function(Map<String, dynamic> value) decode,
  ) async {
    final entry = await read(key);
    if (entry == null) return null;
    try {
      return decode(entry.value);
    } on FormatException {
      try {
        await delete(key);
      } on Object {
        // A failed cleanup only repeats the same miss on the next read.
      }
      return null;
    }
  }
}

/// Explicitly selected in tests; production native builds use Drift. Values are
/// serialized at the boundary, so mutable caller maps cannot mutate the cache.
final class MemoryCacheStore implements CacheStore {
  MemoryCacheStore({
    DateTime Function()? now,
    this.maxEntries = 120,
    this.durable = false,
  }) : assert(maxEntries > 0),
       _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final int maxEntries;

  /// Durable stores never evict; see [CacheStore.new].
  final bool durable;
  final Map<String, String> _values = {};
  bool _closed = false;

  @override
  Future<CacheEntry?> read(String key) async {
    _checkOpen();
    final encoded = _values.remove(key);
    if (encoded == null) return null;
    _values[key] = encoded;
    return decodeEntry(encoded, _now);
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) async {
    _checkOpen();
    _values.remove(key);
    _values[key] = encodeEntry(value, _now(), ttl, revision);
    while (!durable && _values.length > maxEntries) {
      _values.remove(_values.keys.first);
    }
  }

  @override
  Future<void> delete(String key) async {
    _checkOpen();
    _values.remove(key);
  }

  @override
  Future<String?> quarantine(String key) async {
    _checkOpen();
    final raw = _values.remove(key);
    if (raw == null) return null;
    final target = quarantineKey(key, _now());
    _values[target] = raw;
    return target;
  }

  @override
  Future<void> clear() async {
    _checkOpen();
    _values.clear();
  }

  @override
  Future<void> expireAll() async {
    _checkOpen();
    _values.updateAll((_, value) => expireEntry(value, _now()));
  }

  @override
  Future<void> close() async {
    _closed = true;
    _values.clear();
  }

  void _checkOpen() {
    if (_closed) throw StateError('CacheStore is closed');
  }
}

/// Key under which [CacheStore.quarantine] keeps a set-aside entry.
String quarantineKey(String key, DateTime at) =>
    '$key.unreadable.${at.toUtc().microsecondsSinceEpoch}';

String encodeEntry(
  Map<String, dynamic> value,
  DateTime now,
  Duration ttl,
  String? revision,
) {
  final encoded = jsonEncode({
    'value': value,
    'writtenAt': now.toUtc().toIso8601String(),
    'expiresAt': now.add(ttl).toUtc().toIso8601String(),
    'revision': revision,
  });
  if (utf8.encode(encoded).length > 1024 * 1024) {
    throw ArgumentError.value(
      value.length,
      'value',
      'Cache entry exceeds 1 MiB',
    );
  }
  return encoded;
}

CacheEntry decodeEntry(String encoded, DateTime Function() now) {
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return CacheEntry(
    value: Map<String, dynamic>.from(decoded['value'] as Map),
    writtenAt: DateTime.parse(decoded['writtenAt'] as String),
    expiresAt: DateTime.parse(decoded['expiresAt'] as String),
    revision: decoded['revision'] as String?,
    now: now,
  );
}

String expireEntry(String encoded, DateTime now) {
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  decoded['expiresAt'] = now
      .subtract(const Duration(microseconds: 1))
      .toUtc()
      .toIso8601String();
  return jsonEncode(decoded);
}
