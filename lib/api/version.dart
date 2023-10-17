import 'package:http/http.dart' as http;

Future<http.Response> fetchVersion() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/app/version'),
  );
}