import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchPenticostarion() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/collections/penticostarion'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchTriodion() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/collections/triodion'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchOutTriodion() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/collections/out-triodion'),
  ).timeout(apiTimeout);
}
