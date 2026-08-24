import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

Future<http.Response> fetchMonths() {
  return cachedFetch(
    'months',
    () => apiClient.get(Uri.parse('$apiBaseUrl/api/v1/months')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}

Future<http.Response> fetchMonth(String id) {
  return cachedFetch(
    'months:$id',
    () => apiClient.get(Uri.parse('$apiBaseUrl/api/v1/months/$id')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}
