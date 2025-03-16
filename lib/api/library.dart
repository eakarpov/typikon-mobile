import 'package:http/http.dart' as http;
import 'dart:convert';

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

Future<http.Response> batchTexts(List<String> ids) {
  return http.post(
    Uri.parse('https://typikon.su/api/v1/texts/batch'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(ids),
  );
}
