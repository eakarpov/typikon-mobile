import 'package:http/http.dart' as http;

import '../cached_fetch.dart';
import '../constants.dart';

Future<http.Response> fetchMemoryById(String dneslovId) {
  return cachedFetch(
    'dneslov-memory:$dneslovId',
    () => http.get(Uri.parse('$dneslovBaseUrl/api/v0/memories/$dneslovId.json')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchMemoryInfoBySlug(String slug) {
  return cachedFetch(
    'dneslov-memory-slug:$slug',
    () => http.get(Uri.parse('$dneslovBaseUrl/$slug.json')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
