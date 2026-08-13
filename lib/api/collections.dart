import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'constants.dart';

Future<http.Response> fetchPenticostarion() {
  return cachedFetch(
    'collections:penticostarion',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/collections/penticostarion')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}

Future<http.Response> fetchTriodion() {
  return cachedFetch(
    'collections:triodion',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/collections/triodion')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}

Future<http.Response> fetchOutTriodion() {
  return cachedFetch(
    'collections:out-triodion',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/collections/out-triodion')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}
