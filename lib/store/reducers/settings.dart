import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final settingsReducer = combineReducers<Settings>([
  TypedReducer<Settings, ChangeFontSizeAction>(_changeFontSize),
  TypedReducer<Settings, ChangeLineHeightAction>(_changeLineHeight),
  TypedReducer<Settings, ChangeReminderSourceAction>(_changeReminderSource),
  TypedReducer<Settings, ChangeShowAccentsAction>(_changeShowAccents),
  TypedReducer<Settings, ChangeReadingAlignAction>(_changeReadingAlign),
  TypedReducer<Settings, ChangeReadingMeasureAction>(_changeReadingMeasure),
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

Settings _changeShowAccents(Settings state, ChangeShowAccentsAction action) {
  return state.copyWith(showAccents: action.showAccents);
}

Settings _changeReminderSource(Settings state, ChangeReminderSourceAction action) {
  return state.copyWith(reminderSource: action.reminderSource);
}

Settings _changeLineHeight(Settings state, ChangeLineHeightAction action) {
  return state.copyWith(lineHeight: action.lineHeight);
}

Settings _changeReadingAlign(Settings state, ChangeReadingAlignAction action) {
  return state.copyWith(readingAlign: action.readingAlign);
}

Settings _changeReadingMeasure(Settings state, ChangeReadingMeasureAction action) {
  // `null` здесь — «во всю ширину», а не «не меняем»: обычный copyWith такое
  // значение проглотил бы, и ширину нельзя было бы вернуть в полную.
  return state.copyWith(
    readingMeasure: action.readingMeasure,
    clearMeasure: action.readingMeasure == null,
  );
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
    // Сброс цветов чтения не должен трогать ни выбор изданий, ни читаемость:
    // конструктор здесь полный, и пропущенное поле молча вернулось бы к
    // умолчанию.
    lineHeight: state.lineHeight,
    readingAlign: state.readingAlign,
    readingMeasure: state.readingMeasure,
    reminderSource: state.reminderSource,
    showAccents: state.showAccents,
    bibleEditions: state.bibleEditions,
  );
}
