import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final commonReducer = combineReducers<Common>([
  TypedReducer<Common, ChangeCommonDateAction>(_changeCommonDate),
]);

Common _changeCommonDate(Common state, ChangeCommonDateAction action) {
  return Common(
    date: action.date,
  );
}
