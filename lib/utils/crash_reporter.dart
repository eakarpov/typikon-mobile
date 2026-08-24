import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

import '../api/client_errors.dart';
import '../api/constants.dart';

/// Отправка падений на свой же бекенд.
///
/// До этого о поломке можно было узнать единственным способом — если
/// пользователь сам напишет через форму обратной связи. Ручка
/// `/api/client-errors` уже существует для ошибок на сайте и принимает ровно
/// такой набор полей, так что подключать сторонний сервис не понадобилось.
///
/// В отчёт уходит только техническая часть: тип исключения, его сообщение,
/// стек и место в дереве виджетов. Ни текста чтений, ни заметок, ни данных
/// аккаунта здесь нет и быть не должно.

/// Сколько разных ошибок отправляем за один запуск. Падение в build()
/// повторяется на каждом кадре, и без ограничения приложение завалит и сеть,
/// и лог сервера одним и тем же стеком.
const int maxReportsPerSession = 20;

final Set<String> _reported = <String>{};
int _sentCount = 0;

@visibleForTesting
void resetCrashReporterState() {
  _reported.clear();
  _sentCount = 0;
}

@visibleForTesting
int get crashReportsSent => _sentCount;

/// Подпись ошибки: тип, сообщение и верхняя строка стека. Один и тот же сбой,
/// случившийся сто раз подряд, отправляется единожды.
String crashSignature(Object error, StackTrace? stack) {
  final firstFrame = stack
      ?.toString()
      .split("\n")
      .firstWhere((line) => line.trim().isNotEmpty, orElse: () => "");
  return "${error.runtimeType}|$error|$firstFrame";
}

String _platformName() {
  try {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return Platform.operatingSystem;
  } catch (_) {
    return "unknown";
  }
}

/// Тело запроса. Вынесено отдельно от отправки, чтобы проверять его тестом:
/// сервер режет поля по длине сам, но присылать заведомо лишнее незачем.
Map<String, dynamic> buildClientErrorPayload({
  required Object error,
  StackTrace? stack,
  String? context,
  String? platform,
  String? version,
}) {
  final where = [
    if (context != null && context.trim().isNotEmpty) context.trim(),
    platform ?? _platformName(),
    version ?? appVersion,
  ].join(" · ");

  return <String, dynamic>{
    "name": error.runtimeType.toString(),
    "message": error.toString(),
    "stack": stack?.toString() ?? "",
    "where": where,
  };
}

/// Отправляет ошибку, если она новая и лимит запуска не исчерпан.
///
/// Никогда не бросает: провалившийся отчёт об ошибке не должен становиться
/// второй ошибкой.
Future<void> reportCrash(Object error, StackTrace? stack, {String? context}) async {
  if (kDebugMode) return; // при разработке всё и так видно в консоли
  if (_sentCount >= maxReportsPerSession) return;

  final signature = crashSignature(error, stack);
  if (!_reported.add(signature)) return;

  _sentCount++;
  try {
    await sendClientError(buildClientErrorPayload(
      error: error,
      stack: stack,
      context: context,
    ));
  } catch (_) {
    // Нет сети или сервер недоступен — отчёт просто теряется.
  }
}

/// Ставит обработчики на оба пути, которыми ошибка уходит из приложения:
/// падения внутри Flutter (build/layout/paint) и всё, что всплыло из
/// асинхронного кода мимо дерева виджетов.
///
/// Прежние обработчики вызываются как и раньше — вывод в консоль и красный
/// экран при разработке остаются на месте.
void installCrashReporting() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousOnError?.call(details);
    unawaited(reportCrash(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    ));
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(reportCrash(error, stack, context: "platformDispatcher"));
    // false — не считаем ошибку обработанной, пусть runtime отработает как обычно.
    return previousPlatformOnError?.call(error, stack) ?? false;
  };
}
