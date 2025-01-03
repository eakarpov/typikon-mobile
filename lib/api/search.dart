import 'package:http/http.dart' as http;

Future<http.Response> searchString(String search) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/search?query=$search'),
  );
}