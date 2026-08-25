import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';

import '../apiMapper/favourites.dart' as mapper;
import '../apiMapper/session.dart';
import 'actions/actions.dart';
import 'index.dart';
import 'models/models.dart';

/// Синхронизация избранного с сервером.
///
/// Правила простые и от них зависит всё остальное:
///   * не вошёл — сеть не трогаем вовсе, список живёт на устройстве;
///   * вошёл — правда на сервере, а локальный список работает кэшем, чтобы
///     сердечко рисовалось сразу и в офлайне;
///   * не доехавшее лежит в очереди и досылается при первой возможности.
///
/// Ошибки сети наверх не идут: избранное — не то место, где человеку нужно
/// сообщение об ошибке. Не отправилось сейчас — отправится в следующий раз,
/// очередь никуда не денется.

/// Идёт ли синхронизация прямо сейчас: переключение отметок подряд не должно
/// запускать несколько отправок одной и той же очереди.
bool _syncing = false;

typedef PushFavourite = Future<void> Function(String textId, {required bool isAdd});
typedef FetchFavourites = Future<List<String>> Function();
typedef MergeFavourites = Future<List<String>> Function(List<String> textIds);

/// [mergeLocal] — первый вход: локальный список вливается в серверный, а не
/// затирается им.
///
/// Функции работы с сетью передаются параметрами, чтобы синхронизацию можно
/// было проверить тестом, не выходя наружу.
Future<void> syncFavourites(
  Store<AppState> store, {
  bool mergeLocal = false,
  PushFavourite? push,
  FetchFavourites? fetch,
  MergeFavourites? merge,
}) async {
  if (!store.state.auth.isSignedIn) return;
  if (_syncing) return;

  _syncing = true;
  try {
    await _flushQueue(store, push ?? mapper.pushFavourite);

    final ids = mergeLocal
        ? await (merge ?? mapper.mergeFavourites)(store.state.favourites.textIds)
        : await (fetch ?? mapper.fetchFavouriteIds)();
    store.dispatch(FavouritesLoadedAction(ids));
  } on SessionExpiredException {
    // Вход протух — список остаётся локальным до следующего входа, очередь цела.
  } catch (_) {
    // Нет сети или сервер недоступен: пробуем в следующий раз.
  } finally {
    _syncing = false;
  }
}

/// Досылает отложенные изменения по одному и убирает из очереди только те, что
/// сервер подтвердил. Упавшее остаётся в очереди на следующий раз.
Future<void> _flushQueue(Store<AppState> store, PushFavourite push) async {
  final queue = List<PendingFavourite>.from(store.state.favourites.pending);
  if (queue.isEmpty) return;

  final confirmed = <PendingFavourite>[];
  for (final change in queue) {
    try {
      await push(change.textId, isAdd: change.isAdd);
      confirmed.add(change);
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      // Этот текст не сохранился — остальные всё равно пробуем.
    }
  }

  if (confirmed.isNotEmpty) {
    store.dispatch(FavouritesQueueConfirmedAction(confirmed));
  }
}

@visibleForTesting
void resetFavouritesSyncState() {
  _syncing = false;
}
