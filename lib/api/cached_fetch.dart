import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Cache-first HTTP fetch with background revalidation (stale-while-revalidate).
///
/// - No cache yet: awaits [fetcher] directly (today's loading/error behaviour),
///   then writes the successful response to disk.
/// - Cache present and still within [ttl]: returns it, no network call at all.
/// - Cache present but older than [ttl]: returns it immediately, and separately
///   kicks off [fetcher] in the background to refresh the cache for next time.
///   A failed background refresh is swallowed — the caller already got data.
Future<http.Response> cachedFetch(
  String key,
  Future<http.Response> Function() fetcher, {
  Duration ttl = const Duration(hours: 6),
}) async {
  final entry = await _readCache(key);
  if (entry == null) {
    final response = await fetcher();
    if (response.statusCode == 200) {
      unawaited(_writeCache(key, response.body));
    }
    return response;
  }

  final isStale = DateTime.now().difference(entry.cachedAt) >= ttl;
  if (isStale) {
    unawaited(_revalidate(key, fetcher));
  }
  // http.Response defaults to ASCII encoding when no content-type is given,
  // which throws on the Church Slavonic / accented Cyrillic text this API
  // returns. Force UTF-8 so cached bodies round-trip correctly.
  return http.Response(entry.body, 200, headers: {'content-type': 'application/json; charset=utf-8'});
}

Future<void> _revalidate(String key, Future<http.Response> Function() fetcher) async {
  try {
    final response = await fetcher();
    if (response.statusCode == 200) {
      await _writeCache(key, response.body);
    }
  } catch (_) {
    // Offline or the server is unavailable — the caller already has cached data.
  }
}

class _CacheEntry {
  final DateTime cachedAt;
  final String body;

  _CacheEntry(this.cachedAt, this.body);
}

Future<File> _cacheFile(String key) async {
  final baseDir = await getApplicationCacheDirectory();
  final dir = Directory('${baseDir.path}/http_cache');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return File('${dir.path}/${_sanitizeKey(key)}.json');
}

String _sanitizeKey(String key) {
  return key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

Future<_CacheEntry?> _readCache(String key) async {
  try {
    final file = await _cacheFile(key);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    return _CacheEntry(
      DateTime.fromMillisecondsSinceEpoch(decoded['cachedAt']),
      decoded['body'],
    );
  } catch (_) {
    return null;
  }
}

Future<void> _writeCache(String key, String body) async {
  try {
    final file = await _cacheFile(key);
    await file.writeAsString(jsonEncode({
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      'body': body,
    }));
  } catch (_) {
    // Cache is best-effort — a failed write just means no speedup next time.
  }
}

/// Deletes every cached response. Used by the "reset cache" action in Settings.
Future<void> clearHttpCache() async {
  try {
    final baseDir = await getApplicationCacheDirectory();
    final dir = Directory('${baseDir.path}/http_cache');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
