import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchText(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/texts/$id'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchDayByText(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/texts/$id/day'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchLastTexts() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/texts/last'),
  ).timeout(apiTimeout);
}
