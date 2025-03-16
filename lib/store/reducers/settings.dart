import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final settingsReducer = combineReducers<Settings>([
  TypedReducer<Settings, ChangeFontSizeAction>(_changeFontSize),
  TypedReducer<Settings, ChangeBackgroundColorAction>(_changeBackgroundColor),
]);

Settings _changeFontSize(Settings state, ChangeFontSizeAction action) {
  return Settings(fontSize: action.fontSize, backgroundColor: state.backgroundColor);
}

Settings _changeBackgroundColor(Settings state, ChangeBackgroundColorAction action) {
  return Settings(backgroundColor: action.backgroundColor, fontSize: state.fontSize);
}
