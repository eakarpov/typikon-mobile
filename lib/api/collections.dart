import 'package:http/http.dart' as http;

Future<http.Response> fetchPenticostarion() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/collections/penticostarion'),
  );
}

Future<http.Response> fetchTriodion() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/collections/triodion'),
  );
}
