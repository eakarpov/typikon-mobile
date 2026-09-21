import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/store/middleware/sharedPref.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/store.dart';

/// Стор отдаётся уже поднятым с диска.
///
/// Прежде восстановление шло из дерева виджетов, после первого кадра, и всё,
/// что читало стор в `main()`, видело значения по умолчанию: перепривязка
/// пушей при запуске не срабатывала ни у кого и никогда.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("сохранённые настройки видны сразу после создания стора", () async {
    final saved = AppState(
      settings: const Settings().copyWith(reminderSource: "server", fontSize: 27),
      common: Common.init(),
    );
    SharedPreferences.setMockInitialValues({
      APP_STATE_KEY: jsonEncode(saved.toJson()),
    });

    final store = await createReduxStore();

    expect(store.state.settings.remindsFromServer, isTrue);
    expect(store.state.settings.fontSize, 27);
  });

  test("нечитаемая запись не срывает запуск", () async {
    SharedPreferences.setMockInitialValues({APP_STATE_KEY: "{не json"});

    final store = await createReduxStore();

    expect(store.state.settings.remindsFromServer, isFalse);
  });
}
