import 'package:http/http.dart' as http;

Future<http.Response> fetchBooks() {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/library'),
  );
}

Future<http.Response> fetchBook(String id) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/library/$id'),
  );
}
