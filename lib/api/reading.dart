import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'constants.dart';

Future<http.Response> fetchText(String id) {
  return cachedFetch(
    'text:$id',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/texts/$id')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchDayByText(String id) {
  return cachedFetch(
    'text-day:$id',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/texts/$id/day')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchLastTexts() {
  return cachedFetch(
    'texts:last',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/texts/last')).timeout(apiTimeout),
    ttl: const Duration(hours: 6),
  );
}
