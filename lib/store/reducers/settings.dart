import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final settingsReducer = combineReducers<Settings>([
  TypedReducer<Settings, ChangeFontSizeAction>(_changeFontSize),
  TypedReducer<Settings, ChangeBackgroundColorAction>(_changeBackgroundColor),
  TypedReducer<Settings, ChangeFontColorAction>(_changeFontColor),
  TypedReducer<Settings, ChangeThemeModeAction>(_changeThemeMode),
  TypedReducer<Settings, ResetReadingColorsAction>(_resetReadingColors),
]);

Settings _changeFontSize(Settings state, ChangeFontSizeAction action) {
  return state.copyWith(fontSize: action.fontSize);
}

Settings _changeFontColor(Settings state, ChangeFontColorAction action) {
  return state.copyWith(fontColor: action.fontColor);
}

Settings _changeBackgroundColor(Settings state, ChangeBackgroundColorAction action) {
  return state.copyWith(backgroundColor: action.backgroundColor);
}

Settings _changeThemeMode(Settings state, ChangeThemeModeAction action) {
  return state.copyWith(themeMode: action.themeMode);
}

Settings _resetReadingColors(Settings state, ResetReadingColorsAction action) {
  return Settings(
    fontSize: state.fontSize,
    themeMode: state.themeMode,
    backgroundColor: null,
    fontColor: null,
  );
}
