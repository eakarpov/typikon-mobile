import 'package:http/http.dart' as http;

import '../constants.dart';

Future<http.Response> fetchMemoryById(String dneslovId) {
  return http.get(Uri.parse('$dneslovBaseUrl/api/v0/memories/$dneslovId.json')).timeout(apiTimeout);
}

Future<http.Response> fetchMemoryInfoBySlug(String slug) {
  return http.get(Uri.parse('$dneslovBaseUrl/$slug.json')).timeout(apiTimeout);
}
