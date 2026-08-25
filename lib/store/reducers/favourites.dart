import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final favouritesReducer = combineReducers<FavouritesState>([
  TypedReducer<FavouritesState, ToggleFavouriteAction>(_toggle),
  TypedReducer<FavouritesState, FavouritesLoadedAction>(_loaded),
  TypedReducer<FavouritesState, FavouritesQueueConfirmedAction>(_confirmed),
  TypedReducer<FavouritesState, FavouritesClearedAction>(_cleared),
  TypedReducer<FavouritesState, FavouritesRestoredAction>(_restored),
]);

FavouritesState _toggle(FavouritesState state, ToggleFavouriteAction action) {
  return state.toggled(action.textId, at: action.at);
}

FavouritesState _loaded(FavouritesState state, FavouritesLoadedAction action) {
  return state.withServerList(action.textIds);
}

FavouritesState _confirmed(FavouritesState state, FavouritesQueueConfirmedAction action) {
  return state.withoutPending(action.confirmed);
}

FavouritesState _cleared(FavouritesState state, FavouritesClearedAction action) {
  return FavouritesState.init();
}

FavouritesState _restored(FavouritesState state, FavouritesRestoredAction action) {
  return action.state;
}
