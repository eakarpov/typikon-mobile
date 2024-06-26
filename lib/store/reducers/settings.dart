import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final settingsReducer = combineReducers<Settings>([
  TypedReducer<Settings, ChangeFontSizeAction>(_changeFontSize),
]);

Settings _changeFontSize(Settings state, ChangeFontSizeAction action) {
  return Settings(fontSize: action.fontSize);
}
