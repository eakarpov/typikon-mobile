import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchMonths() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/months'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchMonth(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/months/$id'),
  ).timeout(apiTimeout);
}
