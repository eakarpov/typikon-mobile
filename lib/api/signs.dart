import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchSigns() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/signs'),
  ).timeout(apiTimeout);
}
