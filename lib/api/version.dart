import 'package:http/http.dart' as http;

import 'client.dart';
import 'constants.dart';

Future<http.Response> fetchVersion() {
  return apiClient.get(
    Uri.parse('$apiBaseUrl/api/v1/app/version'),
  ).timeout(apiTimeout);
}
