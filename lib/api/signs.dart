import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

Future<http.Response> fetchSigns() {
  return cachedFetch(
    'signs',
    () => apiClient.get(Uri.parse('$apiBaseUrl/api/v1/signs')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
