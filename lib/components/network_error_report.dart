import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/crash_reporter.dart';
import '../utils/network_error_detail.dart';

/// ТИХИЙ СВИДЕТЕЛЬ СЕТЕВОГО ОТКАЗА.
///
/// По экрану причину сетевой неудачи не угадать: и оборванный провод, и
/// сломанный DNS, и системный прокси, и подменённый сертификат, и запрет
/// доступа к сети прошивкой выглядят одинаково — «Нет соединения с интернетом»
/// (или «не удалось загрузить»). Экранные ветки отказов ловят исключение и
/// просто рисуют текст, а `reportCrash` зовётся лишь для настоящих падений —
/// то есть сетевые отказы не уезжают никуда.
///
/// Отсюда эта деталь: она ничего не рисует, но, едва оказавшись в дереве,
/// разово отправляет отказ в `/api/client-errors` — тот же приём, что и у
/// `ApiKeyRefused` из `api/v2/api_key.dart`. Достаточно, чтобы читатель открыл
/// приложение, и причина окажется на сервере, без `adb logcat`.
///
/// В отладке не шлёт ничего: `reportCrash` при `kDebugMode` выходит сразу, и
/// разработчику остаётся сам текст исключения (его показывает `ApiErrorView`).
///
/// Ставится в дерево там, где отказ уже показан, — первым, пустым ребёнком,
/// чтобы не менять ни вид, ни раскладку.
class NetworkErrorReport extends StatefulWidget {
  const NetworkErrorReport({super.key, required this.error, this.context});

  /// Отказ, показанный рядом. Не сетевой и не про сертификат — не отправляем:
  /// сервер отвечает и прочими ошибками, и заваливать его ими незачем.
  final Object? error;

  /// Где не вышло, обычными словами: «сеть: чтения дня». Место в дереве
  /// сервер видит отдельным полем, и без него отчёт не отличить от других.
  final String? context;

  @override
  State<NetworkErrorReport> createState() => _NetworkErrorReportState();
}

class _NetworkErrorReportState extends State<NetworkErrorReport> {
  @override
  void initState() {
    super.initState();
    final error = widget.error;
    if (error == null) return;
    if (!isNetworkError(error) && !isTlsError(error)) return;

    // Стек — отсюда: у отчёта нет своего, а `reportCrash` по нему отсекает
    // повторы одного и того же сбоя (см. `crashSignature`).
    unawaited(reportCrash(error, StackTrace.current, context: widget.context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
