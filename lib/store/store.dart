import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';
import "package:typikon/store/middleware/favourites.dart";
import "package:typikon/store/middleware/sharedPref.dart";

/// Тот же самый стор, что уходит в StoreProvider, но доступный без
/// BuildContext. Нужен слою api/apiMapper: когда сессия на сервере истекла и
/// молча продлить её не вышло, локальный вход надо погасить оттуда, где нет
/// дерева виджетов (см. apiMapper/session.dart).
Store<AppState>? _appStore;

Store<AppState>? get appStore => _appStore;

Future<Store<AppState>> createReduxStore() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final persistence = SharedPrefMiddleware(sharedPreferences);
  final store = Store<AppState>(
    appReducer,
    initialState: AppState.init(),
    middleware: [
      persistence,
      FavouritesMiddleware(sharedPreferences),
    ],
    // AppActions(),
  );
  _appStore = store;

  // Состояние поднимаем здесь, до первого кадра. Нечитаемая запись запуск не
  // срывает: приложение с настройками по умолчанию лучше пустого экрана.
  try {
    await persistence.restore(store);
  } catch (error) {
    debugPrint("Сохранённое состояние не поднялось: $error");
  }
  return store;
}