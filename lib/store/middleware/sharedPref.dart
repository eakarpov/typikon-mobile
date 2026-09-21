import 'dart:async';
import 'dart:convert';

import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/actions/actions.dart';

const String APP_STATE_KEY = "APP_STATE";

class SharedPrefMiddleware extends MiddlewareClass<AppState> {
  final SharedPreferences preferences;

  SharedPrefMiddleware(this.preferences);

  /// Идёт восстановление: его собственные действия на диск не пишем — запись
  /// одна, в конце.
  bool _restoring = false;

  /// Сохраняет состояние после действия — и по тому, что изменилось, а не по
  /// тому, какое действие пришло.
  ///
  /// Прежде здесь стоял перечень сохраняемых действий, и держался он памятью:
  /// настройки читаемости в него однажды не попали и писались на диск лишь
  /// случайно, за компанию с чем-нибудь другим. Сверка сохраняемых частей до и
  /// после действия забыть ничего не может. Она же закрывает давний TODO
  /// «сохранять после действия, а не перед»: запись идёт за `next`.
  ///
  /// Дата в перечне не значится нарочно: она не восстанавливается (приложение
  /// открывается на сегодня), и писать состояние на каждый «День вперёд» незачем.
  @override
  Future<void> call(Store<AppState> store, action, NextDispatcher next) async {
    if (action is FetchItemsAction) {
      await restore(store);
    }

    final before = store.state;
    next(action);
    final after = store.state;

    if (_restoring) return;
    if (before.settings == after.settings &&
        before.favourites == after.favourites &&
        before.auth == after.auth) {
      return;
    }
    await _saveStateToPrefs(after);
  }

  Future _saveStateToPrefs(AppState state) async {
    var stateString = json.encode(state.toJson());
    await preferences.setString(APP_STATE_KEY, stateString);
  }

  /// Ключ, которым избранное хранилось до переезда в стор: просто список id.
  static const String _legacyFavouritesKey = "favourites";

  /// Признак, что старый список уже перенесён. Без него избранное, из которого
  /// человек всё удалил, возвращалось бы из старого ключа при каждом запуске.
  static const String _favouritesMigratedKey = "favouritesMigratedToStore";

  /// Поднимает избранное и, если нужно, переносит список из прежнего хранилища.
  ///
  /// Перенос обязателен: до этой версии избранное жило только под ключом
  /// "favourites", и молча его потерять нельзя. Старый ключ не удаляем — он
  /// ничему не мешает, а при откате на прежнюю версию список останется на месте.
  Future _restoreFavourites(
    Store<AppState> store,
    SharedPreferences prefs,
    FavouritesState restored,
  ) async {
    if (prefs.getBool(_favouritesMigratedKey) == true) {
      store.dispatch(FavouritesRestoredAction(restored));
      return;
    }

    final legacy = prefs.getStringList(_legacyFavouritesKey) ?? [];
    final merged = <String>[
      ...restored.textIds,
      ...legacy.where((id) => id.isNotEmpty && !restored.textIds.contains(id)),
    ];
    store.dispatch(FavouritesRestoredAction(restored.copyWith(textIds: merged)));
    await prefs.setBool(_favouritesMigratedKey, true);
  }

  /// Поднимает сохранённое состояние в стор.
  ///
  /// Зовётся из `createReduxStore` до `runApp`, а не из дерева виджетов: пока
  /// восстановление шло после первого кадра, всё, что читало стор при запуске,
  /// видело значения по умолчанию — перепривязка пушей всегда считала, что
  /// напоминает приложение, и не делала ничего, а тёмная тема мигала светлой.
  Future<void> restore(Store<AppState> store) async {
    _restoring = true;
    try {
      await _restore(store);
    } finally {
      _restoring = false;
    }
    // Одна запись на всё восстановление. Нужна и она: перенос старого избранного
    // помечается сделанным сразу, и без записи перенесённый список жил бы только
    // до конца этого запуска.
    await _saveStateToPrefs(store.state);
  }

  Future<void> _restore(Store<AppState> store) async {
    final SharedPreferences prefs = preferences;
    var stateString = prefs.getString(APP_STATE_KEY);
    if (stateString == null) {
      // Настройки человек мог ни разу не открыть, и тогда сохранённого
      // состояния нет — а избранное под старым ключом всё равно может быть.
      await _restoreFavourites(store, prefs, FavouritesState.init());
      return;
    }
    AppState state = AppState.fromJson(json.decode(stateString));
    await _restoreFavourites(store, prefs, state.favourites);
    store.dispatch(SettingsRestoredAction(state.settings));
    // Дату не восстанавливаем: приложение открывается на сегодня.
    //
    // Вход — прежним действием, а не подменой состояния: на него подписано
    // избранное (см. middleware/favourites.dart), и синхронизация при запуске
    // начинается именно отсюда.
    if (state.auth.isSignedIn && state.auth.userId != null) {
      store.dispatch(SignInSuccessAction(
        userId: state.auth.userId!,
        email: state.auth.email,
        name: state.auth.name,
      ));
      // Отдельным действием, потому что вход собирает `AuthState` заново и
      // признака о себе не знает. Без этой строки раздел поданных записок
      // пропадал бы при каждом запуске до ответа сервера — а спрашивают его
      // раз в сутки.
      if (state.auth.isCommemorator) {
        store.dispatch(CommemoratorCheckedAction(true));
      }
    }
  }
}
