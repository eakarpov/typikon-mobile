import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchDay(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/days/$id'),
  ).timeout(apiTimeout);
}
