import 'package:http/http.dart' as http;

import 'client.dart';
import 'constants.dart';

Future<http.Response> searchString(String search) {
  return apiClient.get(
    Uri.parse('$apiBaseUrl/api/v1/search?query=$search'),
  ).timeout(apiTimeout);
}
