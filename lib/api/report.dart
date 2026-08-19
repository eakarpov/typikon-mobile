import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import '../store/auth_token.dart';

// Только для вошедших — бекенд теперь сам требует валидную сессию
// (userId берётся из cookie, не из тела), см. типikon-web /api/report.
Future<http.Response> reportError({
  required String textId,
  required Map<String, dynamic> selection,
  required String correction,
}) async {
  final headers = <String, String>{
    'Content-Type': 'application/json; charset=UTF-8',
    ...await authHeader(),
  };
  return http.post(
    Uri.parse('$apiBaseUrl/api/report'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'textId': textId,
      'selection': selection,
      'correction': correction,
    }),
  ).timeout(apiTimeout);
}
