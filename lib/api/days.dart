import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

Future<http.Response> fetchDay(String id) {
  return cachedFetch(
    'days:$id',
    () => apiClient.get(Uri.parse('$apiBaseUrl/api/v1/days/$id')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
