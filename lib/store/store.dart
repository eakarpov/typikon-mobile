import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';
import "package:typikon/store/middleware/sharedPref.dart";

Future<Store<AppState>> createReduxStore() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  return Store<AppState>(
    appReducer,
    initialState: AppState.init(),
    middleware: [
      SharedPrefMiddleware(sharedPreferences),
    ],
    // AppActions(),
  );
}