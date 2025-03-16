import 'package:http/http.dart' as http;
import 'dart:convert';

Future<http.Response> sendFeedback(String email, String theme, String value, String captcha, String fingerprint) {
  Map data = {
    'email': email,
    'theme': theme,
    'value': value,
    'captcha': captcha,
  };
  return http.post(
    Uri.parse('https://typikon.su/api/contact'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'x-forwarded-for': fingerprint,
    },
    body: jsonEncode(data),
  );
}

Future<http.Response> getCaptcha(String fingerprint) {
  return http.post(
    Uri.parse('https://typikon.su/api/captcha'),
    headers: <String, String>{
      'x-forwarded-for': fingerprint,
    }
  );
}