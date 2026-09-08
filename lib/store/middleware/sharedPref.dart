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

  @override
  Future<void> call(Store<AppState> store, action, NextDispatcher next) async {
    if (
      action is ChangeFontSizeAction ||
      action is ChangeFontColorAction ||
      action is ChangeBackgroundColorAction ||
      action is ChangeThemeModeAction ||
      action is ChangePreloadTextsAction ||
      action is ChangeBibleEditionsAction ||
      action is ToggleFavouriteAction ||
      action is FavouritesLoadedAction ||
      action is FavouritesQueueConfirmedAction ||
      action is FavouritesClearedAction ||
      action is ResetReadingColorsAction ||
      action is ChangeCommonDateAction ||
      action is SignInSuccessAction ||
      action is SignOutAction
    ) {
      // await _saveStateToPrefs(store.state); // TODO - after store update save to storage, not before!!
      Future.delayed(const Duration(seconds: 0), () {
        store.dispatch(AppSaveAdditional());
      });
    }

    if (action is AppSaveAdditional) {
      await _saveStateToPrefs(store.state);
    }

    if (action is FetchItemsAction) {
      await _loadStateFromPrefs(store);
    }

    next(action);
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

  Future _loadStateFromPrefs(Store<AppState> store) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var stateString = prefs.getString(APP_STATE_KEY);
    if (stateString == null) {
      // Настройки человек мог ни разу не открыть, и тогда сохранённого
      // состояния нет — а избранное под старым ключом всё равно может быть.
      await _restoreFavourites(store, prefs, FavouritesState.init());
      return;
    }
    AppState state = AppState.fromJson(json.decode(stateString));
    await _restoreFavourites(store, prefs, state.favourites);
    store.dispatch(ChangeFontSizeAction(state.settings.fontSize));
    store.dispatch(ChangeThemeModeAction(state.settings.themeMode));
    store.dispatch(ChangeLineHeightAction(state.settings.lineHeight));
    store.dispatch(ChangeReminderSourceAction(state.settings.reminderSource));
    store.dispatch(ChangeReadingAlignAction(state.settings.readingAlign));
    // Отправляем и `null`: «во всю ширину» — такой же выбор, как прочие.
    store.dispatch(ChangeReadingMeasureAction(state.settings.readingMeasure));
    if (state.settings.preloadTexts != null) {
      store.dispatch(ChangePreloadTextsAction(state.settings.preloadTexts!));
    }
    if (state.settings.bibleEditions.isNotEmpty) {
      store.dispatch(ChangeBibleEditionsAction(state.settings.bibleEditions));
    }
    if (state.settings.fontColor != null) {
      store.dispatch(ChangeFontColorAction(state.settings.fontColor!));
    }
    if (state.settings.backgroundColor != null) {
      store.dispatch(ChangeBackgroundColorAction(state.settings.backgroundColor!));
    }
    // store.dispatch(ChangeCommonDateAction(state.common.date)); // Дату пока не сохраняем
    if (state.auth.isSignedIn && state.auth.userId != null) {
      store.dispatch(SignInSuccessAction(
        userId: state.auth.userId!,
        email: state.auth.email,
        name: state.auth.name,
      ));
    }
  }
}
