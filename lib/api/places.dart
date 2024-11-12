import 'package:http/http.dart' as http;

Future<http.Response> fetchPlace(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/places/$id'),
  );
}
