import 'dart:async';

import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../actions/actions.dart';
import '../favourites_sync.dart';
import '../index.dart';

/// Побочные действия вокруг избранного: перенос списка на сервер при первом
/// входе и очистка чужого списка при входе под другим аккаунтом.
class FavouritesMiddleware extends MiddlewareClass<AppState> {
  FavouritesMiddleware(this._prefs);

  final SharedPreferences _prefs;

  /// Под каким аккаунтом локальный список уже вливали в серверный.
  ///
  /// Слияние допустимо ровно один раз на устройство и аккаунт. Повторять его
  /// при каждом запуске нельзя: тогда текст, убранный из избранного на другом
  /// устройстве, воскресал бы здесь снова и снова — локальная копия отправляла
  /// бы его обратно.
  static const String _mergedForKey = "favouritesMergedForUser";

  @override
  void call(Store<AppState> store, action, NextDispatcher next) {
    if (action is! SignInSuccessAction) {
      next(action);
      return;
    }

    final previousUserId = store.state.auth.userId;
    next(action);

    // Другой аккаунт на том же устройстве: его избранное здесь остаться не должно.
    if (previousUserId != null && previousUserId != action.userId) {
      store.dispatch(FavouritesClearedAction());
      unawaited(_prefs.remove(_mergedForKey));
    }

    unawaited(_syncAfterSignIn(store, action.userId));
  }

  Future<void> _syncAfterSignIn(Store<AppState> store, String userId) async {
    final mergedFor = _prefs.getString(_mergedForKey);
    if (mergedFor == userId) {
      await syncFavourites(store);
      return;
    }

    await syncFavourites(store, mergeLocal: true);
    await _prefs.setString(_mergedForKey, userId);
  }
}
