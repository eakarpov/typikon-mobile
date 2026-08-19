import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';

// Запрос с побочным эффектом (создаёт сессию) — не через cachedFetch,
// как и contact.dart.
Future<http.Response> loginWithGoogle({
  required String idToken,
  required int expiresIn,
  required String userIdHint,
  required String deviceId,
}) {
  return http.post(
    Uri.parse('$apiBaseUrl/api/login'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'type': 'Google',
      'data': {
        'access_token': idToken,
        'expires_in': expiresIn,
        'user_id': userIdHint,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'deviceId': deviceId,
    }),
  ).timeout(apiTimeout);
}

Future<http.Response> logout(Map<String, String> authHeaders) {
  return http.post(
    Uri.parse('$apiBaseUrl/api/logout'),
    headers: authHeaders,
  ).timeout(apiTimeout);
}
