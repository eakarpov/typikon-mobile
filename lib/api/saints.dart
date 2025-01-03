import 'package:http/http.dart' as http;

Future<http.Response> fetchTextsBySaint(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/saints/$id'),
  );
}

Future<http.Response> fetchTextsBySaintMention(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/saints/$id/mentions'),
  );
}
