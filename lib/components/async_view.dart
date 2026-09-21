import 'package:flutter/material.dart';

import 'api_error_view.dart';

/// Экран, содержимое которого приходит из сети.
///
/// Одно и то же обрамление — «идёт загрузка», «не вышло, вот кнопка», «пусто»,
/// «потяните, чтобы обновить» — было переписано на полутора десятках страниц, и
/// каждая копия ошибалась по-своему. Разбор находок 2026-09-21 правил их дважды
/// подряд: сперва восемь страниц показывали текст исключения вместо страницы и
/// без «Повторить», потом четыре держали под новой датой данные прежней.
/// Третий раз был бы там же, поэтому обрамление здесь одно.
///
/// **Сверяется `connectionState`, а не одно `hasData`.** `FutureBuilder` при
/// смене будущего держит прежние данные до прихода новых: проверка на `hasData`
/// показывает вчерашние чтения под сегодняшней датой, и ничто на экране не
/// говорит, что идёт загрузка. Это ровно та ошибка, что нашлась на главной, в
/// калькуляторе, в памятях дня и в строке трапезы.
///
/// **Отказ называется своим именем.** Разбор типизированных отказов второй
/// версии API — общий с поиском (`errorViewFor`): «слишком часто» и «раздел не
/// дан по ключу» говорят разное, и «Повторить» показывается только там, где
/// повтор поможет.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    required this.message,
    this.onRetry,
    this.isEmpty,
    this.emptyMessage,
    this.onRefresh,
    this.loading,
    this.hint,
  });

  /// Что грузим. Держится в состоянии страницы, а не создаётся в `build`:
  /// созданное в `build` уходит в сеть на каждую перерисовку (см. поиск).
  final Future<T> future;

  /// Как показать пришедшее.
  final Widget Function(BuildContext context, T data) builder;

  /// Что не удалось загрузить, обычными словами: «Не удалось открыть акафист.»
  final String message;

  /// Повторная попытка. Обычно `() => setState(_load)`. Не передали — кнопки
  /// «Повторить» не будет: есть отказы, которые повтором не лечатся.
  final VoidCallback? onRetry;

  /// Пришло пустое. Отдельно от `null`: пустой список — это ответ, а не отказ.
  final bool Function(T data)? isEmpty;

  /// Что сказать на пустое. Без [isEmpty] не значит ничего.
  final String? emptyMessage;

  /// Потянуть, чтобы обновить. Передан — содержимое оборачивается в
  /// `RefreshIndicator`; обычно это то же самое, что [onRetry].
  final Future<void> Function()? onRefresh;

  /// Чем занять экран на время загрузки. По умолчанию — крутилка посередине.
  final Widget? loading;

  /// Уточнение под сообщением об отказе — например, что источник сторонний.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // Именно так, а не `hasData`: см. оговорку о `connectionState` выше.
        if (snapshot.connectionState != ConnectionState.done) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _short(
              errorViewFor(context, snapshot.error!, message, onRetry, hint: hint));
        }

        if (!snapshot.hasData) {
          // Будущее завершилось без данных и без ошибки — такого быть не
          // должно, но показать пустой экран молча хуже, чем сказать.
          return _short(errorViewFor(context, null, message, onRetry, hint: hint));
        }

        final data = snapshot.data as T;
        if (isEmpty != null && isEmpty!(data)) {
          return _short(searchHint(emptyMessage ?? "Пока пусто."));
        }

        // Содержимое прокручивается само — RefreshIndicator берёт его как есть.
        final content = builder(context, data);
        final refresh = onRefresh;
        return refresh == null
            ? content
            : RefreshIndicator(onRefresh: refresh, child: content);
      },
    );
  }

  /// Короткое состояние: отказ или пустота.
  ///
  /// Потянуть за пустой экран естественнее, чем искать на нём кнопку, но
  /// `RefreshIndicator` требует прокручиваемого потомка, а `Center` с текстом
  /// таковым не является. Поэтому короткое кладётся в список во всю высоту —
  /// иначе жест не отзовётся вовсе. Содержимое так не заворачивают: оно
  /// прокручивается само, и список внутри списка сломал бы прокрутку.
  Widget _short(Widget child) {
    final refresh = onRefresh;
    if (refresh == null) return child;

    return RefreshIndicator(
      onRefresh: refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Дождаться будущего, погасив отказ.
///
/// Нужно для `onRefresh`: кольцо обновления держится, пока не завершится
/// отданное ему будущее, — значит ждать надо, иначе оно исчезнет раньше ответа.
/// А вот пробрасывать отказ оттуда нельзя: показать его — дело [AsyncView],
/// которому то же самое будущее уже отдано, и второй раз он никому не нужен.
Future<void> settle(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {
    // AsyncView покажет отказ сам.
  }
}
