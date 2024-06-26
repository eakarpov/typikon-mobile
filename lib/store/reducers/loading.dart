import 'package:redux/redux.dart';

import '../actions/actions.dart';

final loadingReducer = combineReducers<bool>([
  TypedReducer<bool, AppLoadedAction>(_setLoaded),
  TypedReducer<bool, AppNotLoadedAction>(_setNotLoaded),
]);

bool _setNotLoaded(bool state, action) {
  return false;
}

bool _setLoaded(bool state, action) {
  return true;
}