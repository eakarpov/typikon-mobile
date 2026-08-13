import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'constants.dart';

Future<http.Response> fetchTextsBySaint(String id) {
  return cachedFetch(
    'saints:$id',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/saints/$id')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchTextsBySaintMention(String id) {
  return cachedFetch(
    'saints:$id:mentions',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/saints/$id/mentions')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
