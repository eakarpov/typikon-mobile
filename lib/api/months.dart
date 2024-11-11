import 'package:http/http.dart' as http;

Future<http.Response> fetchMonths() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/months'),
  );
}

Future<http.Response> fetchMonth(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/months/$id'),
  );
}
