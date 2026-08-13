import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchTextsBySaint(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/saints/$id'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchTextsBySaintMention(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/saints/$id/mentions'),
  ).timeout(apiTimeout);
}
