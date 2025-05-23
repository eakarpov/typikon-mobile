import 'package:redux/redux.dart';
import "reducers/loading.dart";
import "reducers/settings.dart";
import "reducers/common.dart";
import "models/models.dart";

AppState appReducer(AppState state, action) {
  return AppState(
    isLoading: loadingReducer(state.isLoading, action),
    settings: settingsReducer(state.settings, action),
    common: commonReducer(state.common, action),
  );
}