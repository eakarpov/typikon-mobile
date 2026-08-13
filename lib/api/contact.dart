import 'package:http/http.dart' as http;
import 'dart:convert';

import 'constants.dart';

Future<http.Response> sendFeedback(String email, String theme, String value, String captcha, String fingerprint) {
  Map data = {
    'email': email,
    'theme': theme,
    'value': value,
    'captcha': captcha,
    'isMobile': true,
  };
  return http.post(
    Uri.parse('$apiBaseUrl/api/contact'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'x-forwarded-for': fingerprint,
    },
    body: jsonEncode(data),
  ).timeout(apiTimeout);
}

Future<http.Response> getCaptcha(String fingerprint) {
  return http.post(
    Uri.parse('$apiBaseUrl/api/captcha'),
    headers: <String, String>{
      'x-forwarded-for': fingerprint,
    }
  ).timeout(apiTimeout);
}
