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
      action is ChangeCommonDateAction
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

  Future _loadStateFromPrefs(Store<AppState> store) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var stateString = prefs.getString(APP_STATE_KEY);
    if (stateString == null) return;
    AppState state = AppState.fromJson(json.decode(stateString));
    store.dispatch(ChangeFontSizeAction(state.settings.fontSize));
    store.dispatch(ChangeFontColorAction(state.settings.fontColor));
    store.dispatch(ChangeBackgroundColorAction(state.settings.backgroundColor));
    // store.dispatch(ChangeCommonDateAction(state.common.date)); // Дату пока не сохраняем
  }
}
