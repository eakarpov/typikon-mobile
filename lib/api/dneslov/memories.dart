import 'package:http/http.dart' as http;

Future<http.Response> fetchMemoryById(String dneslovId) {
  return http.get(Uri.parse('http://dneslov.org/api/v0/memories/$dneslovId.json'));
}

Future<http.Response> fetchMemoryInfoBySlug(String slug) {
  return http.get(Uri.parse('http://dneslov.org/$slug.json'));
}
