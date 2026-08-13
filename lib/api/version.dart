import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchVersion() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/app/version'),
  ).timeout(apiTimeout);
}
