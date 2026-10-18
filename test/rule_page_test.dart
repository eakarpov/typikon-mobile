import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/dto/corpus.dart';
import 'package:typikon/pages/rule_page.dart';
import 'package:typikon/store/rule_marks.dart';

// Правило дня: состав секций, автоподбор канона по дню седмицы, честная
// плашка при пустом подборе, галочки «прочитано» и переключатель рода.

Canon weekdayCanon(String weekday) => Canon(
      id: "canon-$weekday",
      memory: "Память $weekday",
      book: "octoechos",
      service: "matins",
      role: "weekday",
      weekday: weekday,
      tone: 4,
    );

FacetedPage<Canon, CanonFacets> canonsPage(List<Canon> items) =>
    FacetedPage<Canon, CanonFacets>(
      items: items,
      total: items.length,
      limit: 25,
      offset: 0,
      facets: const CanonFacets(),
    );

CalendarDayPartItem gospelItem() => CalendarDayPartItem(
      name: "Ин., 1 зач., I, 1-18.",
      id: null,
      content: "",
      cite: "",
      description: "",
      pericopeSource: "gospel",
      bookSlug: "ioanna",
      verses: null,
      ranges: const <PericopeRange>[
        PericopeRange(chapterFrom: 1, verseFrom: 1, chapterTo: 1, verseTo: 18),
      ],
      isPericope: true,
    );

void main() {
  group("автоподбор", () {
    test("будни: канон ищется по полю weekday", () async {
      final now = DateTime(2026, 10, 12); // понедельник
      final asked = <(String?, String?, String?)>[];

      final data = await loadRuleDay(
        now: now,
        canons: ({query, offset = 0, book, tone, service, role}) async {
          asked.add((book, service, role));
          return canonsPage(<Canon>[
            weekdayCanon("vtornik"),
            weekdayCanon("ponedelnik"),
          ]);
        },
        dayLoader: (_) async => throw Exception("сети нет"),
      );

      expect(asked, contains(("octoechos", "matins", "weekday")));
      expect(data.morningCanon?.id, "canon-ponedelnik");
      expect(data.gospel, isNull);
    });

    test("воскресенье: роль voskresny, фильтра по дню нет", () async {
      final now = DateTime(2026, 10, 11); // воскресенье
      final asked = <(String?, String?, String?)>[];

      final data = await loadRuleDay(
        now: now,
        canons: ({query, offset = 0, book, tone, service, role}) async {
          asked.add((book, service, role));
          return canonsPage(<Canon>[
            const Canon(
              id: "canon-voskresny",
              memory: "Воскресный",
              book: "octoechos",
              service: "matins",
              role: "voskresny",
              tone: 1,
            ),
          ]);
        },
        dayLoader: (_) async => throw Exception("сети нет"),
      );

      expect(asked, contains(("octoechos", "matins", "voskresny")));
      expect(data.morningCanon?.id, "canon-voskresny");
    });

    test("вечерний канон: служба compline, пусто — секции не будет", () async {
      final askedServices = <String?>[];

      var empty = false;
      final data = await loadRuleDay(
        now: DateTime(2026, 10, 12),
        canons: ({query, offset = 0, book, tone, service, role}) async {
          askedServices.add(service);
          if (service == "compline") {
            return canonsPage(empty
                ? <Canon>[]
                : <Canon>[
                    const Canon(
                      id: "canon-vecher",
                      memory: "На сон грядущим",
                      book: "octoechos",
                      service: "compline",
                    ),
                  ]);
          }
          return canonsPage(<Canon>[weekdayCanon("ponedelnik")]);
        },
        dayLoader: (_) async => throw Exception("сети нет"),
      );

      expect(askedServices, contains("compline"));
      expect(data.eveningCanon?.id, "canon-vecher");

      empty = true;
      final emptyData = await loadRuleDay(
        now: DateTime(2026, 10, 12),
        canons: ({query, offset = 0, book, tone, service, role}) async =>
            canonsPage(<Canon>[]),
        dayLoader: (_) async => throw Exception("сети нет"),
      );
      expect(emptyData.eveningCanon, isNull);
    });

    test("зачало Евангелия берётся из дня", () async {
      final withGospel = CalendarDay.fromJson(jsonDecode('''
        {"memories": {"primary": null, "secondary": []},
         "day": {"name": "День", "alias": "day",
           "gospelLiturgy": {"items": [
             {"pericope": {"label": "Ин., 1 зач., I, 1-18.",
               "source": "gospel", "bookSlug": "ioanna",
               "ranges": [{"chapterFrom": 1, "verseFrom": 1,
                           "chapterTo": 1, "verseTo": 18}]}}
           ]}}}
      ''') as Map<String, dynamic>);

      final data = await loadRuleDay(
        now: DateTime(2026, 10, 12),
        canons: ({query, offset = 0, book, tone, service, role}) async =>
            canonsPage(<Canon>[]),
        dayLoader: (_) async => withGospel,
      );

      expect(data.gospel?.bookSlug, "ioanna");
      expect(data.gospel?.name, "Ин., 1 зач., I, 1-18.");
      expect(data.gospel?.ranges, hasLength(1));
    });
  });

  group("экран", () {
    Future<void> pumpRule(
      WidgetTester tester, {
      required Future<RuleDayData> Function() loader,
      Map<String, Object> prefs = const <String, Object>{},
      void Function(String name, Object? arguments)? onPush,
    }) async {
      tester.view.physicalSize = const Size(1200, 6000);
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
        home: RulePage(null, loader: loader),
      ));
      await tester.pumpAndSettle();
    }

    final fullData = RuleDayData(
      morningCanon: weekdayCanon("ponedelnik"),
      gospel: gospelItem(),
    );

    testWidgets("состав: утренние молитвы, канон, Евангелие, на сон; "
        "вечернего канона нет — секции нет", (tester) async {
      await pumpRule(tester, loader: () async => fullData);

      expect(find.text("Правило дня"), findsOneWidget);
      expect(find.text("Молитвы утренние"), findsOneWidget);
      expect(find.text("Канон утренний"), findsOneWidget);
      // Подпись канона: память плюс адрес Октоиха.
      expect(find.textContaining("Память ponedelnik"), findsOneWidget);
      expect(find.text("Глава Евангелия дня"), findsOneWidget);
      expect(find.text("Ин., 1 зач., I, 1-18."), findsOneWidget);
      expect(find.text("Молитвы на сон грядущим"), findsOneWidget);

      expect(find.text("Канон вечерний"), findsNothing);
      expect(find.textContaining("Канон не найден"), findsNothing);
    });

    testWidgets("канон не подобрался: честная плашка и ручной выбор",
        (tester) async {
      final pushed = <String>[];
      await pumpRule(
        tester,
        loader: () async => const RuleDayData(),
        onPush: (name, _) => pushed.add(name),
      );

      expect(find.textContaining("Канон не найден"), findsOneWidget);
      expect(find.text("выбрать вручную"), findsOneWidget);
      // Вечерний канон тоже не нашёлся — секция спряталась вовсе.
      expect(find.text("Канон вечерний"), findsNothing);

      await tester.tap(find.text("выбрать вручную"));
      await tester.pumpAndSettle();
      expect(pushed, contains("/canons"));
    });

    testWidgets("тапы ведут по местам: текст, канон, Евангелие, "
        "последование", (tester) async {
      final pushes = <(String, Object?)>[];
      await pumpRule(
        tester,
        loader: () async => fullData,
        onPush: (name, arguments) => pushes.add((name, arguments)),
      );

      // После каждого тапа возвращаемся: pushed-маршрут накрывает страницу,
      // и без возврата следующий тап не найдёт бывшие виджеты.
      Future<void> tapAndBack(String title) async {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      await tapAndBack("Молитвы утренние");
      await tapAndBack("Канон утренний");
      await tapAndBack("Глава Евангелия дня");
      await tapAndBack("Молитвы на сон грядущим");

      expect(pushes, <(String, Object?)>[
        ("/reading", "67e0472294428ce850c0f9bd"),
        ("/canons", "canon-ponedelnik"),
        ("/bible", "ioanna/1#1:1-1:18"),
        ("/posledovanie",
            "na-son|cu|m|Молитвы на сон грядущим"),
      ]);
    });

    testWidgets("галочки пишут rule_done и прогресс; всё прочитано — "
        "запись стёрта", (tester) async {
      await pumpRule(tester, loader: () async => const RuleDayData());

      final date = dayKey(DateTime.now());
      for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
        expect(checkbox.value, isFalse);
      }

      // Три секции: утренние молитвы, недостающий канон, молитвы на сон.
      final boxes = find.byType(Checkbox);
      await tester.tap(boxes.at(0));
      await tester.pumpAndSettle();
      await tester.tap(boxes.at(1));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool("rule_done:$date:morning_prayers"), isTrue);
      expect(prefs.getBool("rule_done:$date:morning_canon"), isTrue);
      expect(prefs.getBool("rule_done:$date:evening_prayers"), isNull);

      // 2/3 — запись с именем.
      final progress = prefs.getString("reading_progress");
      expect(progress, isNotNull);
      final saved = Map<String, dynamic>.from(
          jsonDecode(progress!) as Map<String, dynamic>);
      expect(saved["rule:$date"]["fraction"], closeTo(2 / 3, 0.001));
      expect(saved["rule:$date"]["name"], "Молитвенное правило");

      // Третья галочка: 1.0 — стор сам стирает запись.
      await tester.tap(boxes.at(2));
      await tester.pumpAndSettle();
      final prefsAfter = await SharedPreferences.getInstance();
      final cleared = prefsAfter.getString("reading_progress");
      expect(cleared == null || !jsonDecode(cleared).containsKey("rule:$date"),
          isTrue);
      expect(find.text("прочитано разделов: 3/3"), findsOneWidget);
    });

    testWidgets("сохранённые галочки показаны", (tester) async {
      final date = dayKey(DateTime.now());
      await pumpRule(
        tester,
        loader: () async => const RuleDayData(),
        prefs: <String, Object>{
          "rule_done:$date:evening_prayers": true,
        },
      );

      final checked = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((checkbox) => checkbox.value);
      expect(checked, <bool?>[false, false, true]);
      expect(find.text("прочитано разделов: 1/3"), findsOneWidget);
    });

    testWidgets("переключатель рода: запоминает и меняет подпись и "
        "аргумент последования", (tester) async {
      final pushes = <(String, Object?)>[];
      await pumpRule(
        tester,
        loader: () async => const RuleDayData(),
        onPush: (name, arguments) => pushes.add((name, arguments)),
      );

      await tester.tap(find.text("ж"));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ruleGenderKey), "f");
      expect(find.text("в женском роде"), findsOneWidget);

      await tester.tap(find.text("Молитвы на сон грядущим"));
      await tester.pumpAndSettle();
      expect(pushes.last,
          ("/posledovanie", "na-son|cu|f|Молитвы на сон грядущим"));
    });

    testWidgets("сохранённый род показан", (tester) async {
      await pumpRule(
        tester,
        loader: () async => const RuleDayData(),
        prefs: const <String, Object>{ruleGenderKey: "f"},
      );

      expect(find.text("в женском роде"), findsOneWidget);
    });
  });
}
