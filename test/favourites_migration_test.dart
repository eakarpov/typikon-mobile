import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/middleware/sharedPref.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

/// Перенос избранного из прежнего хранилища.
///
/// До переезда в стор список лежал в SharedPreferences под ключом "favourites".
/// Потерять его при обновлении нельзя, поэтому проверяем перенос отдельно.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Store<AppState>> storeWith(Map<String, Object> prefsValues) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final store = Store<AppState>(
      appReducer,
      initialState: AppState.init(),
      middleware: [SharedPrefMiddleware(prefs)],
    );
    store.dispatch(FetchItemsAction());
    // Загрузка внутри middleware асинхронная.
    await Future<void>.delayed(Duration.zero);
    return store;
  }

  test("старый список переезжает, даже если настройки ни разу не сохранялись", () async {
    // Самый опасный случай: человек не заходил в настройки, APP_STATE нет вовсе,
    // а избранное есть.
    final store = await storeWith({"favourites": ["a", "b"]});

    expect(store.state.favourites.textIds, ["a", "b"]);
  });

  test("старый список объединяется с уже переехавшим", () async {
    // Сохранённое состояние собираем настоящим toJson, а не руками: так тест
    // ломается, если формат хранения изменится.
    final saved = AppState(
      common: Common.init(),
      favourites: const FavouritesState(textIds: ["новое", "общий"]),
    );
    final store = await storeWith({
      "favourites": ["из-старого", "общий"],
      "APP_STATE": jsonEncode(saved.toJson()),
    });

    expect(store.state.favourites.textIds, ["новое", "общий", "из-старого"]);
  });

  test("перенос делается один раз", () async {
    SharedPreferences.setMockInitialValues({"favourites": ["a"]});
    final prefs = await SharedPreferences.getInstance();

    Store<AppState> makeStore() {
      final store = Store<AppState>(
        appReducer,
        initialState: AppState.init(),
        middleware: [SharedPrefMiddleware(prefs)],
      );
      store.dispatch(FetchItemsAction());
      return store;
    }

    final first = makeStore();
    await Future<void>.delayed(Duration.zero);
    expect(first.state.favourites.textIds, ["a"]);

    // Пользователь убрал единственный текст из избранного — и перезапустил.
    // Старый ключ никуда не делся, но список из него больше не поднимается.
    first.dispatch(ToggleFavouriteAction("a"));
    await Future<void>.delayed(Duration.zero);
    expect(first.state.favourites.textIds, isEmpty);

    final second = makeStore();
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getBool("favouritesMigratedToStore"), isTrue);
    expect(second.state.favourites.textIds, isEmpty);
  });

  test("перенесённый список переживает перезапуск", () async {
    // Перенос помечается сделанным сразу. Пока состояние после него на диск не
    // писалось, список жил до конца запуска: на следующем старый ключ уже не
    // читался, а в сохранённом состоянии избранного не было — и оно пропадало у
    // всякого, кто в первый запуск после обновления не тронул настроек.
    SharedPreferences.setMockInitialValues({"favourites": ["a", "b"]});
    final prefs = await SharedPreferences.getInstance();

    Future<Store<AppState>> launch() async {
      final store = Store<AppState>(
        appReducer,
        initialState: AppState.init(),
        middleware: [SharedPrefMiddleware(prefs)],
      );
      store.dispatch(FetchItemsAction());
      await Future<void>.delayed(Duration.zero);
      return store;
    }

    await launch();
    final second = await launch();

    expect(second.state.favourites.textIds, ["a", "b"]);
  });

  test("пустое прежнее хранилище ничего не ломает", () async {
    final store = await storeWith({});

    expect(store.state.favourites.textIds, isEmpty);
  });
}
