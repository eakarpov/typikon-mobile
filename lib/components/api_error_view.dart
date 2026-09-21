import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../apiMapper/singing.dart';
import '../apiMapper/v2/errors.dart';

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

/// Причина неудачи одной строкой — для всплывающих сообщений о неудавшейся
/// записи.
///
/// То же правило, что у [ApiErrorView], только для случая, когда места под
/// целый экран нет. Показывать текст исключения нельзя ни там, ни здесь:
/// «ClientException with SocketException: Failed host lookup 'www.typikon.su'
/// (OS Error: No address associated with hostname, errno = 7)» выглядит
/// поломкой приложения, хотя это пропавшая сеть, и сделать с этой строкой
/// читателю нечего.
///
/// [what] — что именно не вышло, в прошедшем времени: «имя не записано».
String failureMessage(Object? error, String what) {
  if (isNetworkError(error)) return "Нет связи: $what";

  // Отказы второй версии API несут собственное сообщение сервера, написанное
  // по-русски и для человека, — его и показываем. А приставку «Exception:»,
  // какую печатает голый Exception, срезаем: это слово из отладки.
  final message = error.toString().replaceFirst(RegExp(r"^Exception:\s*"), "").trim();
  if (message.isEmpty || message.length > 200) return what;

  return message;
}

/// Дружелюбная замена сырому `Text('${future.error}')` в ветках `hasError`.
///
/// Показывать пользователю текст исключения бессмысленно: он ничего не может
/// с ним сделать, а строка вида `ClientException: Failed host lookup` выглядит
/// как поломка приложения, хотя обычно это просто пропавшая сеть.
class ApiErrorView extends StatelessWidget {
  /// Ошибка из FutureBuilder — нужна только чтобы отличить обрыв сети от
  /// прочих неудач.
  final Object? error;

  /// Что именно не удалось загрузить, обычными словами.
  final String message;

  /// Свой текст на случай отсутствия сети, если общего мало.
  final String? offlineMessage;

  /// Уточнение под сообщением — например, что источник данных сторонний.
  final String? hint;

  final VoidCallback? onRetry;

  const ApiErrorView({
    super.key,
    required this.error,
    required this.message,
    this.offlineMessage,
    this.hint,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final offline = isNetworkError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(offline ? Icons.wifi_off : Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              offline ? (offlineMessage ?? "Нет соединения с интернетом.") : message,
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text("Повторить")),
            ],
          ],
        ),
      ),
    );
  }
}

/// Короткая подсказка вместо списка — «ещё не искали», «ничего не нашлось».
Widget searchHint(String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );

/// Отказ, названный своим именем.
///
/// Заводился для поиска, теперь общий — им же пользуется [AsyncView], так что
/// типизированные отказы второй версии API доходят до всякой страницы, а не
/// только до выдачи поиска.
///
/// Четыре случая, и каждый читателю говорит разное: слишком короткий запрос —
/// его дело поправимо; корпус не выложен — не его вина и повторять бесполезно;
/// раздел не дан по ключу — тем более; слишком часто — надо подождать. Общее
/// «не удалось выполнить поиск» на всех четырёх было бы неправдой в трёх, и в
/// трёх же предлагало бы кнопку «Повторить» там, где повтор не поможет.
Widget errorViewFor(
  BuildContext context,
  Object? error,
  String fallbackMessage,
  VoidCallback? onRetry,
) {
  if (error is SearchQueryTooShort) {
    return searchHint("Введите хотя бы ${error.minLength} символа.");
  }

  if (error is CorpusUnavailableException) {
    return ApiErrorView(
      error: error,
      message: error.message,
      hint: "Это не поломка приложения: корпус певческих текстов выкладывается "
          "на сервер отдельно, и сейчас его там нет. Повторять бесполезно.",
    );
  }

  if (error is ApiUnauthorizedException) {
    // Повторять нечего: раздел не дают, а не он сломался.
    return ApiErrorView(error: error, message: error.message);
  }

  if (error is ApiRateLimitedException) {
    return ApiErrorView(error: error, message: error.message, hint: error.hint, onRetry: onRetry);
  }

  return ApiErrorView(error: error, message: fallbackMessage, onRetry: onRetry);
}
