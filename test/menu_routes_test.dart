import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/pages/menu_entries.dart';
import 'package:typikon/pages/section_page.dart';
import 'package:typikon/routes.dart';

// Меню и маршруты — два перечня одного и того же, и расходятся они молча.
// Пункт, которому не отвечает ни один `case`, не гаснет и не темнеет: нажатие
// роняет приложение с «Could not find a generator for route», и узнаём мы об
// этом от того, кто нажал.
//
// Поэтому сверяем обе стороны: каждый пункт описи разрешается в маршрут, и
// каждый маршрут, живущий без аргумента, либо значится в меню, либо назван
// здесь нарочно.

/// Маршруты, которых в меню нет и не должно быть.
///
/// Открываются не выбором раздела, а по ходу чтения: карточкой, ссылкой из
/// текста, толчком уведомления. Список именной, а не условие: заведя новый
/// экран, придётся ответить себе, место ему в меню или здесь.
const Set<String> unlistedRoutes = <String>{
  "/search", // из шапки ящика, значком
  "/days", // день из календаря
  "/reading", // текст из любого перечня
  "/pericope", // зачало из указателя
  "/incipit", // зачин из поиска
  "/saints", // досье из памяти
  "/pomyannik/upcoming", // из помянника
  "/pomyannik/zapiska", // из помянника
};

Route<dynamic>? resolve(String route) => generateRoute(
      RouteSettings(name: route),
      hasSkippedUpdate: true,
      skipUpdateWindow: (_) {},
    );

/// Имена маршрутов, разбираемые `generateRoute`, — прямо из его исходника.
///
/// Разбор текстом, а не отражением: `case` — не данные, и вытащить их иначе
/// нечем. Зато перечень не приходится повторять руками, а значит, он не
/// устареет.
Set<String> routesInSource() {
  final source = File("lib/routes.dart").readAsStringSync();
  final names = RegExp(r"""case\s+["'](/[^"']*)["']:""")
      .allMatches(source)
      .map((m) => m.group(1)!)
      .toSet();

  // Два маршрута названы постоянными из самой описи, а не строкой.
  names.addAll(<String>[corpusRoute, handbookRoute]);
  return names;
}

void main() {
  group("пункт меню открывается", () {
    test("каждый маршрут описи разбирается без аргумента", () {
      // Ровно та ошибка, что жила в «/places»: ветвь без аргумента ничего не
      // возвращала, и пункт меню уронил бы приложение.
      for (final entry in allMenuEntries) {
        expect(resolve(entry.route), isNotNull,
            reason: "«${entry.title}» ведёт на ${entry.route}, "
                "а такого маршрута generateRoute не знает");
      }
    });

    test("незнакомый маршрут честно возвращает null", () {
      expect(resolve("/такого-нет"), isNull);
    });
  });

  group("маршрут не теряется", () {
    test("всё, что открывается само по себе, названо в меню или в исключениях",
        () {
      final listed = allMenuEntries.map((e) => e.route).toSet();

      for (final route in routesInSource()) {
        if (resolve(route) == null) continue; // нужен аргумент — не наш случай
        expect(listed.contains(route) || unlistedRoutes.contains(route), isTrue,
            reason: "маршрут $route открывается без аргумента, но в меню его "
                "нет — либо добавить пункт, либо назвать в unlistedRoutes");
      }
    });

    test("в исключениях нет лишних имён", () {
      // Список исключений устаревает так же молча, как и меню.
      final known = routesInSource();
      for (final route in unlistedRoutes) {
        expect(known.contains(route), isTrue,
            reason: "$route числится исключением, но такого маршрута больше нет");
      }
    });
  });

  group("опись", () {
    test("имена маршрутов не повторяются", () {
      final routes = allMenuEntries.map((e) => e.route).toList();
      expect(routes.toSet().length, routes.length,
          reason: "один раздел показан дважды — выбор становится загадкой");
    });

    test("у каждого раздела в «Собрании» и «Пособиях» есть пояснение", () {
      // Ради пояснений экраны и заведены: без него строка на экране-разделе
      // ничем не лучше строки в ящике.
      for (final entry in <MenuEntry>[...corpusEntries, ...handbookEntries]) {
        expect(entry.hint, isNotNull, reason: "«${entry.title}» без пояснения");
        expect(entry.hint!.trim(), isNotEmpty);
      }
    });
  });

  group("экран-раздел", () {
    testWidgets("показывает все пункты с пояснениями", (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SectionPage(null, title: "Собрание", entries: corpusEntries),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final entry in corpusEntries) {
        expect(find.text(entry.title), findsOneWidget);
        expect(find.text(entry.hint!), findsOneWidget);
      }
    });
  });
}
