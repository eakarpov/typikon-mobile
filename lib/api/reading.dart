import 'package:http/http.dart' as http;

Future<http.Response> fetchText(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/texts/$id'),
  );
}
