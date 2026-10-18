import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/apiMapper/session.dart';
import 'package:typikon/dto/pomyannik.dart';
import 'package:typikon/pages/psalter_sorokoust_page.dart';
import 'package:typikon/store/psalter_mode.dart';
import 'package:typikon/store/rule_marks.dart' show dayKey;

// Сорокоуст: день от даты преставления («День N из 40»), кафизма дня в
// поминальном режиме, честный фолбэк без даты, выбор лица из помянника.
// Загрузчик лиц подменён: сеть в тесте не нужна.

String daysAgo(int days) {
  final now = DateTime.now();
  return dayKey(now.subtract(Duration(days: days)));
}

Person _died(String id, String name, int days) =>
    Person(id: id, name: name, kind: departed, died: daysAgo(days));

class Captures {
  final pushed = <String>[];
  final args = <Object?>[];
}

Future<Captures> pumpSorokoust(
  WidgetTester tester, {
  Future<List<Person>> Function()? personsLoader,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final captures = Captures();
  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: (settings) {
      captures.pushed.add(settings.name ?? "");
      captures.args.add(settings.arguments);
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: const Text("открыто"),
        ),
      );
    },
    home: PsalterSorokoustPage(
      personsLoader: personsLoader ?? () async => <Person>[],
    ),
  ));
  await tester.pumpAndSettle();
  return captures;
}

void main() {
  testWidgets("выбранное лицо: день из даты преставления и кафизма дня",
      (tester) async {
    final captures = await pumpSorokoust(
      tester,
      personsLoader: () async => <Person>[_died("p1", "Николай", 4)],
      prefs: const <String, Object>{"psalter_sorokoust_person": "p1"},
    );

    expect(find.text("Николай"), findsOneWidget);
    expect(find.textContaining("День 5 из 40"), findsOneWidget);

    await tester.tap(find.text("Читать кафизму дня"));
    await tester.pumpAndSettle();

    expect(captures.pushed.last, "/psalter/kathisma");
    // День 5 → пятая кафизма, поминальный режим.
    expect(captures.args.last, "5|d");
  });

  testWidgets("сорок дней — кафизма по кругу (день 40 → 20-я)", (tester) async {
    final captures = await pumpSorokoust(
      tester,
      personsLoader: () async => <Person>[_died("p1", "Николай", 39)],
      prefs: const <String, Object>{"psalter_sorokoust_person": "p1"},
    );

    expect(find.textContaining("День 40 из 40"), findsOneWidget);
    await tester.tap(find.text("Читать кафизму дня"));
    await tester.pumpAndSettle();
    expect(captures.args.last, "20|d");
  });

  testWidgets("без даты преставления день честно неизвестен", (tester) async {
    await pumpSorokoust(
      tester,
      personsLoader: () async => <Person>[_died("p1", "Николай", 4).copyWith(died: null)],
      prefs: const <String, Object>{"psalter_sorokoust_person": "p1"},
    );

    expect(
      find.text("День неизвестен, дата преставления не указана."),
      findsOneWidget,
    );
    expect(find.text("Читать кафизму дня"), findsNothing);
  });

  testWidgets("выбор лица диалогом пишет ключ и обновляет экран",
      (tester) async {
    await pumpSorokoust(
      tester,
      personsLoader: () async => <Person>[
        _died("p1", "Николай", 4),
        _died("p2", "Анна", 10),
      ],
    );

    expect(find.text("Усопший не выбран"), findsOneWidget);

    await tester.tap(find.text("Выбрать…"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Анна"));
    await tester.pumpAndSettle();

    expect(await psalterSorokoustPerson(), "p2");
    expect(find.text("Анна"), findsOneWidget);
    expect(find.textContaining("День 11 из 40"), findsOneWidget);
    expect(find.text("Усопший не выбран"), findsNothing);
  });

  testWidgets("выбранное в ключе лицо показывается с датой", (tester) async {
    await pumpSorokoust(
      tester,
      personsLoader: () async => <Person>[_died("p1", "Николай", 4)],
      prefs: const <String, Object>{"psalter_sorokoust_person": "p1"},
    );

    expect(find.text("Николай"), findsOneWidget);
    expect(find.textContaining("†"), findsOneWidget);
  });

  testWidgets("ключа нет и лица убрано из помянника — просят выбрать снова",
      (tester) async {
    await pumpSorokoust(
      tester,
      personsLoader: () async => <Person>[_died("p1", "Николай", 4)],
      prefs: const <String, Object>{"psalter_sorokoust_person": "нет-такого"},
    );

    expect(find.text("Усопший не выбран"), findsOneWidget);
  });

  testWidgets("помянник пуст: честная пустота, без кнопки чтения",
      (tester) async {
    await pumpSorokoust(tester);

    expect(find.text("О упокоении пока никто не вписан."), findsOneWidget);
    expect(find.text("Читать кафизму дня"), findsNothing);
  });

  testWidgets("сессия истекла — просим войти, а не «не удалось»",
      (tester) async {
    await pumpSorokoust(
      tester,
      personsLoader: () async => throw const SessionExpiredException(),
    );

    expect(find.textContaining("Сорокоуст читается с именами"), findsOneWidget);
    expect(find.text("Войти"), findsOneWidget);
    expect(find.text("Читать кафизму дня"), findsNothing);
  });

  testWidgets("сбой сети — честный отказ с повтором", (tester) async {
    await pumpSorokoust(
      tester,
      personsLoader: () async => throw Exception("нет сети"),
    );

    expect(find.text("Не удалось открыть помянник."), findsOneWidget);
    expect(find.text("Повторить"), findsOneWidget);
  });
}
