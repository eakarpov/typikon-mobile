import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/pages/menu_entries.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/store.dart';
import 'package:typikon/utils/commemorator.dart';

/// Приём записок открывают не входом, а подтверждением в личном кабинете.
///
/// Отдельной ручки, чтобы о подтверждении спросить, у сервера нет: единственный
/// признак — как он отвечает на сам раздел. Прежде раздел показывался всякому
/// вошедшему, и неподтверждённый открывал заглушку «приём вам не открыт» —
/// обещание возможности, которой у него нет.
void main() {
  // createReduxStore читает SharedPreferences — это плагин платформы.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetCommemoratorCheck();
    resetCommemoratorSource();
  });

  tearDown(resetCommemoratorSource);

  Future<Store<AppState>> signedIn() async {
    final store = await createReduxStore();
    store.dispatch(SignInSuccessAction(userId: "u1"));
    return store;
  }

  test("пункт меню объявлен видимым только подтверждённому", () {
    final entry = allMenuEntries.firstWhere((e) => e.route == "/pomyannik/prinyatye");

    expect(entry.visibility, MenuVisibility.commemorator);
  });

  test("сервер ответил разделом — признак ставится", () async {
    final store = await signedIn();
    askServer = () async => true;

    await refreshCommemorator();

    expect(store.state.auth.isCommemorator, isTrue);
  });

  test("сервер отказал в разделе — это ответ, а не поломка", () async {
    final store = await signedIn();
    store.dispatch(CommemoratorCheckedAction(true));
    askServer = () async => throw const ApiUnauthorizedException("Приём не открыт");

    await refreshCommemorator();

    expect(store.state.auth.isCommemorator, isFalse);
  });

  test("отказ сети прежнего ответа не отменяет", () async {
    // Погасить раздел из-за того, что метро проехало туннель, значит отнять его
    // у того, кому он открыт.
    final store = await signedIn();
    store.dispatch(CommemoratorCheckedAction(true));
    resetCommemoratorCheck();
    askServer = () async => throw Exception("нет сети");

    await refreshCommemorator();

    expect(store.state.auth.isCommemorator, isTrue);
  });

  test("второй раз подряд не спрашиваем", () async {
    await signedIn();
    var asked = 0;
    askServer = () async {
      asked++;
      return true;
    };

    await refreshCommemorator();
    await refreshCommemorator();

    expect(asked, 1);
  });

  test("невошедшего не спрашиваем вовсе", () async {
    await createReduxStore();
    var asked = 0;
    askServer = () async {
      asked++;
      return true;
    };

    await refreshCommemorator();

    expect(asked, 0);
  });

  test("выход стирает признак", () async {
    final store = await signedIn();
    store.dispatch(CommemoratorCheckedAction(true));

    store.dispatch(SignOutAction());

    expect(store.state.auth.isCommemorator, isFalse);
  });

  test("признак переживает перезапуск", () async {
    // Иначе раздел пропадал бы при каждом запуске до ответа сервера.
    // Без очистки в setUp: здесь нужен тот же диск между двумя запусками.
    final store = await signedIn();
    store.dispatch(CommemoratorCheckedAction(true));
    // Запись на диск идёт за действием и не ждёт его отправителя.
    await pumpEventQueue();

    final restarted = await createReduxStore();

    expect(restarted.state.auth.isCommemorator, isTrue);
  });
}
