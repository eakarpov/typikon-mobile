import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final settingsReducer = combineReducers<Settings>([
  TypedReducer<Settings, ChangeFontSizeAction>(_changeFontSize),
  TypedReducer<Settings, ChangeBackgroundColorAction>(_changeBackgroundColor),
  TypedReducer<Settings, ChangeFontColorAction>(_changeFontColor),
]);

Settings _changeFontSize(Settings state, ChangeFontSizeAction action) {
  return Settings(
      fontSize: action.fontSize,

      backgroundColor: state.backgroundColor,
      fontColor: state.fontColor,
  );
}

Settings _changeFontColor(Settings state, ChangeFontColorAction action) {
  return Settings(
    fontColor: action.fontColor,

    backgroundColor: state.backgroundColor,
    fontSize: state.fontSize,
  );
}

Settings _changeBackgroundColor(Settings state, ChangeBackgroundColorAction action) {
  return Settings(
    backgroundColor: action.backgroundColor,

    fontSize: state.fontSize,
    fontColor: state.fontColor,
  );
}
