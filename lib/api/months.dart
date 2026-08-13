import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'constants.dart';

Future<http.Response> fetchMonths() {
  return cachedFetch(
    'months',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/months')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}

Future<http.Response> fetchMonth(String id) {
  return cachedFetch(
    'months:$id',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/months/$id')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}
