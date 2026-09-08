import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _sessionCookieKey = "session_cookie";

const FlutterSecureStorage _storage = FlutterSecureStorage();

Future<void> saveSessionCookie(String cookieValue) {
  return _storage.write(key: _sessionCookieKey, value: cookieValue);
}

/// Откуда берётся кука. Подменяется тестами: защищённое хранилище — плагин
/// платформы, и в `flutter test` его нет вовсе. Тот же приём, что у
/// `readRawApiKey` в `lib/api/v2/api_key.dart`.
@visibleForTesting
Future<String?> Function() readSessionCookie = _fromSecureStorage;

Future<String?> _fromSecureStorage() => _storage.read(key: _sessionCookieKey);

@visibleForTesting
void resetSessionCookieSource() {
  readSessionCookie = _fromSecureStorage;
}

Future<String?> getSessionCookie() => readSessionCookie();

Future<void> clearSessionCookie() {
  return _storage.delete(key: _sessionCookieKey);
}

/// Заголовок для будущих защищённых запросов — сервер видит cookie ровно
/// так же, как если бы её прислал браузер, httpOnly для не-браузерного
/// клиента ограничением не является.
Future<Map<String, String>> authHeader() async {
  final cookie = await getSessionCookie();
  if (cookie == null) return {};
  return {'Cookie': 'session=$cookie'};
}
