import 'dart:convert';

import 'package:http/http.dart' as http;

// Конверт ошибки второй версии API — `{"error":{"code","message"}}`.
//
// Живёт в слое запросов, а не разбора, потому что читает его и сам слой
// запросов: по коду решается, объявлять ли ключ негодным. Ошибиться тут дорого
// (см. `markApiKeyRefused`), а две копии разбора разошлись бы молча.

Map<String, dynamic>? _errorObject(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final error = decoded['error'];
    return error is Map ? Map<String, dynamic>.from(error) : null;
  } catch (_) {
    return null;
  }
}

/// Код ошибки из тела ответа; `null` — тело не разобралось.
String? v2ErrorCode(http.Response response) {
  final error = _errorObject(response);
  final code = error?['code'];
  return code is String && code.isNotEmpty ? code : null;
}

/// Сообщение сервера, если оно есть; иначе [fallback].
String v2ErrorMessage(http.Response response, String fallback) {
  final error = _errorObject(response);
  final message = error?['message'];
  return message is String && message.trim().isNotEmpty ? message.trim() : fallback;
}
