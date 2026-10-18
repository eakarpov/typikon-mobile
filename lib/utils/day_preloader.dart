import 'dart:async';

import 'package:flutter/foundation.dart';

import '../apiMapper/reading.dart';
import '../apiMapper/ordo.dart';
import '../api/ordo.dart';

/// Предварительная загрузка текстов дня.
///
/// Кэш до сих пор был чисто реактивным: он грелся только тем, что человек уже
/// открыл. Но главный сценарий у приложения обратный — открыть чтения в храме,
/// где сети может не быть вовсе. Поэтому, показав день, тихо докачиваем сами
/// тексты: сеть в этот момент, скорее всего, ещё есть.
///
/// Ничего не показываем и ни на что не влияем: это фон, который либо успел,
/// либо нет. Ошибки гасятся, страница о них не знает.

/// Сколько текстов тянем за раз. Больше — незачем: выигрыш во времени
/// небольшой, а занимать собой канал и батарею ради фоновой задачи не стоит.
const int preloadConcurrency = 2;

/// Верхняя граница на день. В обычный день текстов около десятка, но в
/// праздник со всеми местами службы их бывает заметно больше, и качать всё
/// подряд без предела — не то, чего ждёт человек с мобильным интернетом.
const int maxPreloadedTexts = 25;

/// true, пока идёт предзагрузка: повторный заход на главную не должен запускать
/// вторую такую же пачку запросов поверх первой.
bool _running = false;

/// Тексты, уже прошедшие через предзагрузку в этом запуске. Кэш на диске и так
/// не даст сходить в сеть повторно, но и лишний разбор json ни к чему.
final Set<String> _preloaded = <String>{};

@visibleForTesting
void resetPreloaderState() {
  _running = false;
  _preloaded.clear();
  _ordoLoaded.clear();
  _ordoRunning.clear();
}

/// [fetch] подменяется в тестах; по умолчанию это обычная загрузка текста,
/// которая идёт через cachedFetch и в сеть не ходит, если текст уже в кэше.
Future<void> preloadTexts(
  List<String> textIds, {
  Future<void> Function(String id)? fetch,
}) async {
  if (_running) return;

  final pending = textIds
      .where((id) => id.isNotEmpty && !_preloaded.contains(id))
      .take(maxPreloadedTexts)
      .toList();
  if (pending.isEmpty) return;

  final warm = fetch ?? _defaultFetch;

  _running = true;
  try {
    for (var i = 0; i < pending.length; i += preloadConcurrency) {
      final chunk = pending.skip(i).take(preloadConcurrency);
      await Future.wait(chunk.map((id) => _warmOne(id, warm)));
    }
  } finally {
    _running = false;
  }
}

Future<void> _defaultFetch(String id) => getText(id);

Future<void> _warmOne(String id, Future<void> Function(String id) fetch) async {
  try {
    await fetch(id);
    _preloaded.add(id);
  } catch (_) {
    // Нет сети или текст не отдался — не беда, откроется обычным путём.
  }
}

/// Общие ворота предзагрузки чтений и службы дня: вызывается только при
/// включённой пользователем загрузке. Ошибку ordo главная не показывает.
Future<void> preloadDay(DateTime date, List<String> textIds) async {
  await Future.wait([preloadTexts(textIds), preloadOrdo(date)]);
}

final Set<String> _ordoLoaded = <String>{};
final Set<String> _ordoRunning = <String>{};
Future<void> preloadOrdo(
  DateTime date, {
  Future<void> Function(DateTime)? fetch,
}) async {
  final key = ordoDayDate(date);
  if (_ordoLoaded.contains(key) || !_ordoRunning.add(key)) return;
  try {
    if (fetch != null) {
      await fetch(date);
    } else {
      await getOrdoServices(date);
    }
    _ordoLoaded.add(key);
  } catch (_) {
    // Можно повторить при следующем показе дня.
  } finally {
    _ordoRunning.remove(key);
  }
}
