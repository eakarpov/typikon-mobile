import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// ОПОЗНАНИЕ СЕТЕВОЙ НЕУДАЧИ И ЕЁ ПРИЧИНЫ.
///
/// Экран нарочно не показывает читателю текст исключения: «ClientException with
/// SocketException: Failed host lookup 'www.typikon.su' (OS Error: No address
/// associated with hostname, errno = 7)» выглядит поломкой приложения, хотя это
/// пропавшая сеть, и сделать с этой строкой человеку нечего (см.
/// `lib/components/api_error_view.dart`).
///
/// Но это же «нет соединения» скрывает и куда более разные вещи, и на MIUI
/// особенно: сломанный DNS, системный прокси, подменённый сертификат и запрет
/// сетевого доступа прошивкой выглядят на экране одинаково. Разница видна
/// только в типе исключения и коде `osError`, поэтому она вынесена сюда —
/// отдельным слоем, который зовут отладочный текст на экране и отчёт на сервер.

/// Похоже ли, что запрос не дошёл до сервера, а не сервер ответил ошибкой.
///
/// Таймаут сюда тоже входит: для пользователя "сеть не отвечает" и "сервер
/// молчит шесть секунд" — одно и то же состояние.
bool isNetworkError(Object? error) {
  if (error is SocketException || error is TimeoutException || error is http.ClientException) {
    return true;
  }
  final message = error.toString();
  return message.contains('SocketException') ||
      message.contains('TimeoutException') ||
      message.contains('Failed host lookup');
}

/// Не удалось проверить сертификат сервера.
///
/// Отдельно от «нет сети», и это не придирка: при такой поломке связь у
/// человека есть, менять ему нечего, а «Повторить» не поможет, пока не починят
/// сервер. Сказать тут «нет соединения с интернетом» — значит отправить его
/// чинить свой вай-фай.
///
/// Так выглядела выкладка на typikon.info: сервер отдавал свой сертификат без
/// промежуточного. Android, в отличие от curl и браузера, недостающее звено
/// сам не дозагружает, и в приложении отказывали разом все страницы. Ошибка
/// при этом шла мимо обёрток `http` (там ловятся только `SocketException` и
/// `HttpException`), а значит и мимо [isNetworkError], — человек видел общее
/// «не удалось загрузить», по которому причину не угадать.
bool isTlsError(Object? error) {
  if (error is HandshakeException || error is TlsException) return true;
  final message = error.toString();
  return message.contains("HandshakeException") ||
      message.contains("CERTIFICATE_VERIFY_FAILED");
}

/// Причина сетевой неудачи одной строкой — для разработчика, а не читателя.
///
/// **Код `osError` здесь главное.** Он и различает случаи, которые на экране
/// неразличимы: `ENOTFOUND` (7) — сломанный резолв или пойманный прокси;
/// `ECONNREFUSED`/`ECONNRESET` — соединение отвергли; `ENETUNREACH`/
/// `EHOSTUNREACH` — маршрута нет, что типично для запрета доступа к сети;
/// `ETIMEDOUT` — висит. Тип исключения добавляет к этому своё: `SocketException`
/// — сеть, `HandshakeException` — сертификат.
String describeNetworkError(Object? error) {
  if (error == null) return "ошибка не записана";

  final osError = switch (error) {
    SocketException(:final osError) => osError,
    TlsException(:final osError) => osError,
    _ => null,
  };

  final buffer = StringBuffer(error.runtimeType.toString());
  if (osError != null) {
    buffer.write(" · osError ${osError.errorCode}: ${osError.message}");
  }
  buffer.write(" · $error");
  return buffer.toString();
}
