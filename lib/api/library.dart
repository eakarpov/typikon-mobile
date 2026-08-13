import 'package:http/http.dart' as http;
import 'dart:convert';

import 'cached_fetch.dart';
import 'constants.dart';

Future<http.Response> fetchBooks() {
  return cachedFetch(
    'library',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/library')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchBook(String id) {
  return cachedFetch(
    'library:$id',
    () => http.get(Uri.parse('$apiBaseUrl/api/v1/library/$id')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
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
