import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/dto/posledovanie.dart';
import 'package:typikon/pages/posledovanie_page.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

// Чтение последования рядами: заголовок, лицо, текст, повтор, поклон,
// рубрика-курсив. Экран общий — его открывают и правило дня, и причастная
// раскладка.

Future<void> pumpPosledovanie(
  WidgetTester tester, {
  required Future<Posledovanie> Function() loader,
}) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: PosledovaniePage(
        null,
        title: "Молитвы на сон грядущим",
        posledovanieKey: "na-son",
        loader: loader,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Posledovanie sample() => Posledovanie(
      key: "na-son",
      lang: "cu",
      rows: const <PosledovanieRow>[
        PosledovanieRow(
          label: "Моли́тва 1-я",
          lead: "Иере́й",
          text: "Господу пое́мъ",
        ),
        PosledovanieRow(
          text: "Сла́ва Отцу",
          repeatCount: 3,
          poklon: true,
          note: "И поклоня́ются до земли́.",
        ),
      ],
    );

void main() {
  testWidgets("заголовок экрана — из аргумента, ряды — по местам", (tester) async {
    await pumpPosledovanie(tester, loader: () async => sample());

    expect(find.text("Молитвы на сон грядущим"), findsOneWidget);
    expect(find.text("Моли́тва 1-я"), findsOneWidget);
    expect(find.text("Иере́й:"), findsOneWidget);
    expect(find.text("Господу пое́мъ"), findsOneWidget);
    expect(find.text("Сла́ва Отцу"), findsOneWidget);
  });

  testWidgets("повтор, поклон и рубрика", (tester) async {
    await pumpPosledovanie(tester, loader: () async => sample());

    expect(find.text("по 3"), findsOneWidget);
    expect(find.text("(поклон)"), findsOneWidget);
    expect(find.text("И поклоня́ются до земли́."), findsOneWidget);

    // Рубрика — курсивом, как указание книги, а не текст молитвы.
    final note = tester.widget<Text>(
        find.text("И поклоня́ются до земли́."));
    expect(note.style?.fontStyle, FontStyle.italic);
  });

  testWidgets("пустой ответ честно назван", (tester) async {
    await pumpPosledovanie(
      tester,
      loader: () async => const Posledovanie(key: "na-son", lang: "cu"),
    );

    expect(
        find.text("Рядов этого последования в ответе нет."), findsOneWidget);
  });

  testWidgets("отказ показывает повтор", (tester) async {
    await pumpPosledovanie(
      tester,
      loader: () async => throw Exception("сети нет"),
    );
    await tester.pump();

    expect(find.text("Не удалось открыть последование."), findsOneWidget);
    expect(find.text("Повторить"), findsOneWidget);
  });

  test("аргумент маршрута собирается и разбирается", () {
    final raw = posledovanieRouteArgument("na-son", "Молитвы на сон грядущим",
        gender: "f");
    final target = parsePosledovanieArgument(raw);

    expect(target, isNotNull);
    expect(target!.key, "na-son");
    expect(target.lang, "cu");
    expect(target.gender, "f");
    expect(target.title, "Молитвы на сон грядущим");

    expect(parsePosledovanieArgument(""), isNull);
    expect(parsePosledovanieArgument("только-ключ"), isNull);
    expect(
      parsePosledovanieArgument("na-son|cu|m|"), // пустой заголовок
      isNull,
    );
  });
}
