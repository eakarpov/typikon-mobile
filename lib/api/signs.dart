import 'package:http/http.dart' as http;

Future<http.Response> fetchSigns() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/signs'),
  );
}