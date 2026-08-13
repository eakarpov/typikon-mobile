import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchPlace(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/places/$id'),
  ).timeout(apiTimeout);
}
