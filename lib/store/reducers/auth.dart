import 'package:redux/redux.dart';

import '../actions/actions.dart';
import '../models/models.dart';

final authReducer = combineReducers<AuthState>([
  TypedReducer<AuthState, SignInSuccessAction>(_signIn),
  TypedReducer<AuthState, SignOutAction>(_signOut),
  TypedReducer<AuthState, CommemoratorCheckedAction>(_commemorator),
]);

AuthState _commemorator(AuthState state, CommemoratorCheckedAction action) {
  // Вошедшему и только ему: признак без учётной записи ничего не значит.
  if (!state.isSignedIn) return state;
  return state.copyWith(isCommemorator: action.isCommemorator);
}

AuthState _signIn(AuthState state, SignInSuccessAction action) {
  return AuthState(
    isSignedIn: true,
    userId: action.userId,
    email: action.email,
    name: action.name,
  );
}

AuthState _signOut(AuthState state, SignOutAction action) {
  return const AuthState();
}
