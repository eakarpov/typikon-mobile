import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import '../store/auth_token.dart';

// Личные заметки — только для вошедших, не кэшируем (как и batchTexts):
// сервер — единственный источник правды, общий с вебом.
Future<http.Response> fetchUserNotes({String? textId}) async {
  final headers = await authHeader();
  final uri = textId != null
      ? Uri.parse('$apiBaseUrl/api/user-notes?textId=$textId')
      : Uri.parse('$apiBaseUrl/api/user-notes');
  return http.get(uri, headers: headers).timeout(apiTimeout);
}

Future<http.Response> createUserNote({
  required String textId,
  required Map<String, dynamic> selection,
  required String note,
}) async {
  final headers = <String, String>{
    'Content-Type': 'application/json; charset=UTF-8',
    ...await authHeader(),
  };
  return http.post(
    Uri.parse('$apiBaseUrl/api/user-notes'),
    headers: headers,
    body: jsonEncode({'textId': textId, 'selection': selection, 'note': note}),
  ).timeout(apiTimeout);
}

Future<http.Response> updateUserNote(String id, String note) async {
  final headers = <String, String>{
    'Content-Type': 'application/json; charset=UTF-8',
    ...await authHeader(),
  };
  return http.put(
    Uri.parse('$apiBaseUrl/api/user-notes/$id'),
    headers: headers,
    body: jsonEncode({'note': note}),
  ).timeout(apiTimeout);
}

Future<http.Response> deleteUserNote(String id) async {
  final headers = await authHeader();
  return http.delete(Uri.parse('$apiBaseUrl/api/user-notes/$id'), headers: headers).timeout(apiTimeout);
}
