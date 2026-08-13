import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> searchString(String search) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/search?query=$search'),
  ).timeout(apiTimeout);
}
