import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/pages/bible_page.dart';
import 'package:typikon/pages/outside_page.dart';
import 'package:typikon/pages/place_page.dart';
import 'package:typikon/pages/places_page.dart';
import 'package:typikon/pages/signs_page.dart';

/// Экран загрузки на дюжине страниц был обёрнут в Positioned.fill вне Stack.
/// Positioned — это ParentDataWidget, и вне Stack он бросает исключение: пока
/// шла загрузка, вместо страницы рисовался серо-белый ErrorWidget, не знающий
/// ни о какой теме. На медленной сети это и был "стоковый белый интерфейс".
void main() {
  testWidgets("страница вне Триодного цикла грузится без исключений", (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: OutsidePage(null),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("оглавление Библии грузится без исключений", (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: BiblePage(null),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("страница памятей грузится без исключений", (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: SignsPage(null),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("указатель мест грузится без исключений", (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: PlacesPage(null),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("страница места грузится без исключений", (tester) async {
    // Две загрузки врозь: пока не пришла карточка, показывается один кружок, а
    // не два — и уж точно не сырой текст исключения, как было прежде.
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: PlacePage(null, id: "ierusalim"),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
