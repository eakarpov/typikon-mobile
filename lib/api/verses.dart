import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

Future<http.Response> fetchVerses(String textId) {
  return cachedFetch(
    'verses:$textId',
    () => apiClient.get(Uri.parse('$apiBaseUrl/api/v1/texts/$textId/verses')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
