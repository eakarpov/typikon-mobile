import 'package:http/http.dart' as http;
import 'dart:convert';

import 'constants.dart';

Future<http.Response> fetchBooks() {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/library'),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchBook(String id) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/library/$id'),
  ).timeout(apiTimeout);
}

Future<http.Response> batchTexts(List<String> ids) {
  return http.post(
    Uri.parse('$apiBaseUrl/api/v1/texts/batch'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(ids),
  ).timeout(apiTimeout);
}
