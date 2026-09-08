import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
