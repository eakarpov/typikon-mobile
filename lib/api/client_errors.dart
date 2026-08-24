import 'dart:convert';

import 'package:http/http.dart' as http;

import 'client.dart';
import 'constants.dart';

/// Отправка упавшего исключения на бекенд.
///
/// Ручка та же, что принимает ошибки браузера с сайта (`/api/client-errors`),
/// поэтому отдельный сервис вроде Sentry не нужен: сервер уже умеет их
/// принимать, ограничивать частоту и складывать в свой лог.
///
/// Таймаут короче общего: отчёт об ошибке — фон, и висеть на нём пятнадцать
/// секунд незачем.
Future<http.Response> sendClientError(Map<String, dynamic> payload) {
  return apiClient.post(
    Uri.parse('$apiBaseUrl/api/client-errors'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(payload),
  ).timeout(const Duration(seconds: 8));
}
