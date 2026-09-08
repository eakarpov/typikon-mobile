import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final settingsReducer = combineReducers<Settings>([
  TypedReducer<Settings, ChangeFontSizeAction>(_changeFontSize),
  TypedReducer<Settings, ChangeBackgroundColorAction>(_changeBackgroundColor),
  TypedReducer<Settings, ChangeFontColorAction>(_changeFontColor),
  TypedReducer<Settings, ChangeThemeModeAction>(_changeThemeMode),
  TypedReducer<Settings, ChangePreloadTextsAction>(_changePreloadTexts),
  TypedReducer<Settings, ChangeBibleEditionsAction>(_changeBibleEditions),
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

Settings _changePreloadTexts(Settings state, ChangePreloadTextsAction action) {
  return state.copyWith(preloadTexts: action.preloadTexts);
}

Settings _changeBibleEditions(Settings state, ChangeBibleEditionsAction action) {
  return state.copyWith(bibleEditions: action.bibleEditions);
}

Settings _resetReadingColors(Settings state, ResetReadingColorsAction action) {
  return Settings(
    fontSize: state.fontSize,
    themeMode: state.themeMode,
    backgroundColor: null,
    fontColor: null,
    preloadTexts: state.preloadTexts,
    // Сброс цветов чтения не должен трогать выбор изданий: конструктор здесь
    // полный, и пропущенное поле молча вернулось бы к умолчанию.
    bibleEditions: state.bibleEditions,
  );
}
