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
