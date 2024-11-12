import 'package:http/http.dart' as http;

Future<http.Response> fetchText(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/texts/$id'),
  );
}

Future<http.Response> fetchDayByText(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/texts/$id/day'),
  );
}

Future<http.Response> fetchLastTexts() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/texts/last'),
  );
}
