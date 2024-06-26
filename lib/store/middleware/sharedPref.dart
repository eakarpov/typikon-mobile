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
    if (action is ChangeFontSizeAction) {
      print(action);
      await _saveStateToPrefs(store.state, action.fontSize); // TODO - after store update save to storage, not before!!
    }

    if (action is FetchItemsAction) {
      print("here it is");
      await _loadStateFromPrefs(store);
    }

    next(action);
  }

  Future _saveStateToPrefs(AppState state, int newFontSize) async {
    // state.settings.fontSize = newFontSize;
    var stateString = json.encode(state.toJson());
    print(stateString);
    await preferences.setString(APP_STATE_KEY, stateString);
  }

  Future _loadStateFromPrefs(Store<AppState> store) async {
    var stateString = preferences.getString(APP_STATE_KEY);
    print(stateString);
    if (stateString == null) return;
    AppState state = AppState.fromJson(json.decode(stateString));
    store.dispatch(ChangeFontSizeAction(state.settings.fontSize));
  }
}
