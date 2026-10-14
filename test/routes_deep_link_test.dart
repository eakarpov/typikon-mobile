import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/pages/bible_chapter_page.dart';
import 'package:typikon/pages/text_page.dart';
import 'package:typikon/routes.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

// Входящие ссылки сайта: «Поделиться» отправляет адрес вида
// https://www.typikon.info/reading/<id>, и открывший его должен попасть в тот
// же экран, что и из списка чтений. Deep link движок превращает путь в имя
// маршрута — здесь то, что имя становится экраном, а не onUnknownRoute.

Route<dynamic>? resolve(String name) => generateRoute(
      RouteSettings(name: name),
      hasSkippedUpdate: true,
      skipUpdateWindow: (_) {},
    );

void main() {
  group("разбор адреса входящей ссылки", () {
    test("id берётся после префикса", () {
      expect(deepLinkArgument("/reading/abc", "/reading/"), "abc");
    });

    test("query-часть и конечный слэш отбрасываются", () {
      expect(deepLinkArgument("/reading/abc?x=1", "/reading/"), "abc");
      expect(deepLinkArgument("/reading/abc/?x=1", "/reading/"), "abc");
      expect(deepLinkArgument("/bible/matfeya/19?utm=share", "/bible/"), "matfeya/19");
    });

    test("пустой хвост — не ссылка", () {
      expect(deepLinkArgument("/reading/", "/reading/"), isNull);
      expect(deepLinkArgument("/reading/?x=1", "/reading/"), isNull);
      expect(deepLinkArgument("/library", "/reading/"), isNull);
    });
  });

  group("ссылка разрешается в экран", () {
    Future<void> openLink(WidgetTester tester, String link) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          onGenerateRoute: (settings) => generateRoute(
            settings,
            hasSkippedUpdate: true,
            skipUpdateWindow: (_) {},
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.pushNamed(context, link),
              child: const Text("открыть"),
            ),
          ),
        ),
      ));
      await tester.tap(find.text("открыть"));
      // Страницы грузят текст по сети: двух кадров хватает, чтобы она встала
      // в дерево, а дальше её FutureBuilder покажет ошибку загрузки — нам
      // достаточно, что это нужный экран.
      await tester.pump();
      await tester.pump();
    }

    testWidgets("/reading/<id> открывает экран текста", (tester) async {
      await openLink(tester, "/reading/abc?x=1");
      expect(find.byType(TextPage), findsOneWidget);
    });

    testWidgets("/bible/<книга>/<глава> открывает главу Библии", (tester) async {
      await openLink(tester, "/bible/matfeya/19");
      expect(find.byType(BibleChapterPage), findsOneWidget);
    });
  });

  group("маски не трогают обычные маршруты", () {
    test("/reading без id по-прежнему не разрешается", () {
      // Аргумент обязателен: маска не должна его подменять пустым.
      expect(resolve("/reading"), isNull);
    });

    test("похожие имена не попадают под маску", () {
      expect(resolve("/readings/abc"), isNull);
      expect(resolve("/biblex/matfeya/19"), isNull);
    });
  });
}
