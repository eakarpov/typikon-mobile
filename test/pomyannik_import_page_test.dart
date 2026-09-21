import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pomyannik.dart';
import 'package:typikon/pages/pomyannik_import_page.dart';

/// Экран загрузки списка: разбор показывается ДО записи.
///
/// Чин, отделённый от имени, и родство из скобок — догадки. Догадка, которую
/// видно и можно снять, не то же, что догадка, записанная молча.
void main() {
  final vocabulary = Vocabulary.fromJson(
    jsonDecode(File("test/fixtures/pomyannik_vocabulary.json").readAsStringSync()),
  );

  Future<void> pump(WidgetTester tester, {String kind = living}) =>
      tester.pumpWidget(MaterialApp(
        home: PomyannikImportPage(kind: kind, vocabulary: vocabulary),
      ));

  /// Искать в строках разбора, а не по всему экрану: тот же текст лежит и в
  /// поле ввода, откуда его разбирали.
  Finder inRows(String text) => find.descendant(
        of: find.byType(ListTile),
        matching: find.textContaining(text),
      );

  Future<void> parse(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.tap(find.text("Разобрать"));
    await tester.pumpAndSettle();
  }

  testWidgets("до разбора ничего не предлагается записать", (tester) async {
    await pump(tester);

    expect(find.textContaining("Вписать"), findsNothing);
  });

  testWidgets("разбор показывает имя, чин и исходную строку", (tester) async {
    await pump(tester);
    await parse(tester, "прот. Иоанна (крёстный)");

    expect(inRows("Иоанна"), findsWidgets);
    // Чин и родство названы словами, и рядом — строка, как она стояла в списке.
    expect(inRows("протоиерей"), findsOneWidget);
    expect(inRows("крёстный"), findsOneWidget);
    expect(inRows("прот. Иоанна (крёстный)"), findsOneWidget);
  });

  testWidgets("снятое имя остаётся видно и не идёт в счёт", (tester) async {
    await pump(tester);
    await parse(tester, "Иоанна\nМарии\nНиколая");

    expect(find.text("Вписать 3"), findsOneWidget);

    // По самой строке: имя стоит и в заголовке, и в исходной строке под ним.
    await tester.tap(find.widgetWithText(ListTile, "Марии").first);
    await tester.pumpAndSettle();

    // Имя не исчезло: молчаливая пропажа строки из списка родни хуже зачёркнутой.
    expect(inRows("Марии"), findsWidgets);
    expect(find.text("Вписать 2"), findsOneWidget);
  });

  testWidgets("заголовки столбцов сосчитаны, а не пропали молча", (tester) async {
    await pump(tester);
    await parse(tester, "О здравии:\nИоанна\nМарии");

    expect(find.text("Вписать 2"), findsOneWidget);
    expect(find.textContaining("Заголовки столбцов пропущены: 1"), findsOneWidget);
  });

  testWidgets("столбец берётся у вкладки, а не угадывается", (tester) async {
    // «Убиенный» бывает только об усопших.
    await pump(tester, kind: departed);
    await parse(tester, "убиенного Георгия");

    expect(inRows("убиенный"), findsOneWidget);
  });

  testWidgets("список без имён говорит об этом", (tester) async {
    await pump(tester);
    await parse(tester, "О здравии:\n\n— ");

    expect(find.textContaining("Имён в списке не нашлось"), findsOneWidget);
    expect(find.textContaining("Вписать"), findsNothing);
  });
}
