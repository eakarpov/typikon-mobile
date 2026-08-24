import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

Future<http.Response> fetchPlace(String id) {
  return cachedFetch(
    'places:$id',
    () => apiClient.get(Uri.parse('$apiBaseUrl/api/v1/places/$id')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
