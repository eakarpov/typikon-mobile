import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/pages/communion_page.dart';

// Подготовка к Причащению: раскладка вечеров от сегодня до дня включительно,
// каноны по кругу из трёх, отметки «прочитано» и прогресс.

Future<void> pumpCommunion(
  WidgetTester tester, {
  required DateTime today,
  DateTime? initialDate,
  Map<String, Object> prefs = const <String, Object>{},
  void Function(String name, Object? arguments)? onPush,
}) async {
  tester.view.physicalSize = const Size(1200, 10000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: onPush == null
        ? null
        : (settings) {
            onPush(settings.name ?? "", settings.arguments);
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(),
                body: const Text("открыто"),
              ),
            );
          },
    home: CommunionPage(
      null,
      today: today,
      initialDate: initialDate,
      trapeza: (_) => const SizedBox.shrink(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final today = DateTime(2026, 10, 14);

  testWidgets("раскладка: вечера от сегодня до дня включительно, день несёт "
      "благодарственные", (tester) async {
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 16),
    );

    expect(find.text("Причастие"), findsOneWidget);
    expect(find.text("День причащения"), findsOneWidget);
    expect(find.text("16 октября 2026"), findsOneWidget);

    // Вечера 14, 15 и 16 — включительно.
    expect(find.text("Сегодня вечером"), findsOneWidget);
    expect(find.text("Вечер · 15 октября 2026"), findsOneWidget);
    expect(find.text("Вечер · 16 октября 2026"), findsOneWidget);
    expect(find.text("Вечер · 17 октября 2026"), findsNothing);

    expect(find.text("Канон молебный"), findsNWidgets(3));
    expect(find.text("Молитвы ко Причащению"), findsNWidgets(3));
    expect(find.text("Причащение · 16 октября 2026"), findsOneWidget);
    expect(find.text("Благодарственные молитвы"), findsOneWidget);
    expect(find.text("после Святого Причащения"), findsOneWidget);
  });

  testWidgets("каноны идут по кругу: покаянный, Богородице, Ангелу, снова "
      "покаянный", (tester) async {
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 17),
    );

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    final canonNames = tiles
        .where((tile) =>
            tile.title is Text && (tile.title as Text).data == "Канон молебный")
        .map((tile) => (tile.subtitle as Text).data)
        .toList();
    expect(canonNames, <String?>[
      "Канон покаянный",
      "Канон Богородице",
      "Канон Ангелу хранителю",
      "Канон покаянный",
    ]);
  });

    testWidgets("тапы ведут: канон — в карточку, молитвы — в последование",
      (tester) async {
    final pushes = <(String, Object?)>[];
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 15),
      onPush: (name, arguments) => pushes.add((name, arguments)),
    );

    // После каждого тапа возвращаемся: pushed-маршрут накрывает страницу,
    // и без возврата следующий тап не найдёт бывшие виджеты.
    Future<void> tapAndBack(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tapAndBack(find.text("Канон молебный").first);
    await tapAndBack(find.text("Молитвы ко Причащению").first);
    await tapAndBack(find.text("Благодарственные молитвы"));

    expect(pushes, <(String, Object?)>[
      ("/canons", "molebny-kanon-pokayanny"),
      ("/posledovanie", "ko-prichashcheniyu|cu|m|Молитвы ко Причащению"),
      ("/posledovanie", "blagodarstvennye|cu|m|Благодарственные молитвы"),
    ]);
  });

  testWidgets("галочки пишут communion_done и прогресс; всё прочитано — "
      "запись стёрта", (tester) async {
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 15), // 2 вечера × 2 + благодарственные
    );

    final boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(5));

    for (var i = 0; i < 4; i++) {
      await tester.tap(boxes.at(i));
      await tester.pumpAndSettle();
    }

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool("communion_done:2026-10-15:evening0:canon"), isTrue);
    expect(
        prefs.getBool("communion_done:2026-10-15:evening0:posledovanie"),
        isTrue);
    expect(prefs.getBool("communion_done:2026-10-15:day:blagodarstvennye"),
        isNull);

    final progress = prefs.getString("reading_progress");
    expect(progress, isNotNull);
    final saved = Map<String, dynamic>.from(
        jsonDecode(progress!) as Map<String, dynamic>);
    expect(saved["communion:2026-10-15"]["fraction"], closeTo(4 / 5, 0.001));
    expect(saved["communion:2026-10-15"]["name"], "Причастие: 15 октября 2026");

    // Последняя галочка: 1.0 — стор сам стирает запись.
    await tester.tap(boxes.at(4));
    await tester.pumpAndSettle();
    final prefsAfter = await SharedPreferences.getInstance();
    final cleared = prefsAfter.getString("reading_progress");
    expect(
        cleared == null ||
            !jsonDecode(cleared).containsKey("communion:2026-10-15"),
        isTrue);
    expect(find.text("прочитано: 5/5"), findsOneWidget);
  });

  testWidgets("сохранённые галочки показаны", (tester) async {
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 14),
      prefs: const <String, Object>{
        "communion_done:2026-10-14:evening0:posledovanie": true,
      },
    );

    final checked = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((checkbox) => checkbox.value)
        .toList();
    expect(checked, <bool?>[false, true, false]);
    expect(find.text("прочитано: 1/3"), findsOneWidget);
  });
}
