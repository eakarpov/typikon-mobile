import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../apiMapper/singing.dart';
import '../apiMapper/v2/errors.dart';
import '../utils/network_error_detail.dart';
import 'network_error_report.dart';

// Опознание сетевой неудачи и разбор её причины переехали в
// utils/network_error_detail.dart: их зовут и этот экран, и отчёт на сервер.
// Экспорт оставлен, чтобы не менять десяток импортов по страницам и тестам.
export '../utils/network_error_detail.dart' show isNetworkError, isTlsError;

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
  if (isTlsError(error)) return "Сервер не отвечает как надо: $what";
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
    final tls = isTlsError(error);
    final offline = !tls && isNetworkError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ничего не рисует: разово отправляет сетевой отказ на сервер, чтобы
            // у читателя причина не оставалась за общим «нет соединения».
            NetworkErrorReport(error: error, context: "сеть: $message"),
            Icon(
              tls
                  ? Icons.gpp_bad_outlined
                  : (offline ? Icons.wifi_off : Icons.error_outline),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              tls
                  ? "Не удалось установить защищённое соединение с сервером."
                  : (offline ? (offlineMessage ?? "Нет соединения с интернетом.") : message),
              textAlign: TextAlign.center,
            ),
            if (tls) ...[
              const SizedBox(height: 8),
              Text(
                "Связь у вас есть — дело на стороне сервера. "
                "Остаётся подождать и попробовать позже.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            // Только в отладке и только про сеть: читателю сырое исключение
            // ничего не говорит (см. `failureMessage`), а разработчику именно
            // оно и нужно — на MIUI одинаковое «нет соединения» прячет и DNS, и
            // прокси, и сертификат, и запрет доступа прошивкой.
            if (kDebugMode && (tls || offline)) ...[
              const SizedBox(height: 8),
              Text(
                "Отладка: ${describeNetworkError(error)}",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
  VoidCallback? onRetry, {
  String? hint,
}) {
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

  if (error is ApiNotFoundException) {
    // Честный ответ сервера («Такого стиха нет ни в одном издании собрания»),
    // а не поломка: повторять нечего.
    return ApiErrorView(error: error, message: error.message);
  }

  if (error is ApiRateLimitedException) {
    return ApiErrorView(error: error, message: error.message, hint: error.hint, onRetry: onRetry);
  }

  return ApiErrorView(
    error: error,
    message: fallbackMessage,
    hint: hint,
    onRetry: onRetry,
  );
}
