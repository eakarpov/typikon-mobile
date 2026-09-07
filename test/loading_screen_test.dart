import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/pages/outside_page.dart';
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

  testWidgets("страница памятей грузится без исключений", (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: SignsPage(null),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
