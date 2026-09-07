import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api/v2/api_key.dart';

/// Разбор отказов второй версии API.
///
/// Вторая версия отвечает на всякую ошибку одинаково — `{"error":{"code",
/// "message"}}`, — и это стоит использовать вместо общего «не удалось загрузить».
/// Сообщения там написаны по-русски и для человека: «Такой книги нет ни в каноне,
/// ни в приложении», «В этих изданиях такой главы нет». Второе — вовсе не ошибка
/// приложения, а честный ответ (Исход 37–39 напечатан без разбивки на стихи,
/// Апокалипсиса нет в китайском Новом Завете), и подменять его своим текстом
/// значило бы потерять точность.
///
/// Отдельно от всего этого стоит обрыв связи: он остаётся зоной `isNetworkError`
/// и `ApiErrorView`. Путать нельзя — «нет соединения» на честный `404` однажды
/// уже сбило бы отладку.

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

/// Сколько ждать до повтора — из заголовка `Retry-After`.
///
/// Заголовок задаётся секундами, но по спецификации может прийти и датой; вторую
/// форму сервер не шлёт, и разбирать её ради полноты незачем — при неразобранном
/// значении просто не показываем число.
Duration? v2RetryAfter(http.Response response) {
  final raw = response.headers['retry-after'];
  final seconds = int.tryParse(raw?.trim() ?? '');
  if (seconds == null || seconds <= 0) return null;
  return Duration(seconds: seconds);
}

/// Слишком часто. Не ошибка приложения и не поломка — надо подождать.
class ApiRateLimitedException implements Exception {
  const ApiRateLimitedException({this.retryAfter, required this.anonymous});

  final Duration? retryAfter;

  /// Запрос ушёл без ключа — потому ли, что его нет в сборке, или потому, что
  /// сервер его не признал. Тогда предел — шестьдесят запросов в час на адрес
  /// сети, и «слишком часто» может означать не спешку читателя, а то, что за
  /// одним приходским Wi-Fi сидит десяток человек.
  final bool anonymous;

  String get message {
    final wait = retryAfter;
    if (wait == null) return 'Слишком много запросов. Попробуйте чуть позже.';
    return 'Слишком много запросов. Повторите через ${wait.inSeconds} с.';
  }

  /// Вторая строка для экрана — только когда есть что объяснить.
  String? get hint => anonymous
      ? 'Запрос ушёл без ключа доступа: без него сервер отпускает 60 запросов в '
          'час на один адрес сети — один на всех, кто в этой сети сидит.'
      : null;

  @override
  String toString() => message;
}

/// Раздел не отдан: ключа нет, он не признан или не даёт этого раздела.
///
/// Своё исключение нужно, чтобы не потерять сообщение сервера. Оно объясняет
/// причину точнее нашего («Этот раздел доступен по ключу») и говорит, где ключ
/// взять, — а общее «не удалось выполнить поиск» на его месте было бы прямым
/// враньём: поиск не сломался, его просто не дали.
class ApiUnauthorizedException implements Exception {
  const ApiUnauthorizedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Сервер честно ответил, что такого нет. Сообщение — его собственное.
class ApiNotFoundException implements Exception {
  const ApiNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Превращает неуспешный ответ в исключение и бросает его.
///
/// Возвращает `Never`, чтобы вызывающий маппер писался в одну ветку:
/// `if (response.statusCode == 200) return X.fromJson(...); throwV2Error(...)`.
Never throwV2Error(http.Response response, String fallback) {
  if (response.statusCode == 429) {
    throw ApiRateLimitedException(
      retryAfter: v2RetryAfter(response),
      // Ключа нет в сборке или сервер его не признал — снаружи это одно и то же.
      anonymous: apiKey == null,
    );
  }

  if (response.statusCode == 401 || response.statusCode == 403) {
    throw ApiUnauthorizedException(v2ErrorMessage(response, fallback));
  }

  if (response.statusCode == 404) {
    throw ApiNotFoundException(v2ErrorMessage(response, fallback));
  }

  throw Exception(v2ErrorMessage(response, fallback));
}
