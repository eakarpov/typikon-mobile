import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/components/selection_menu.dart';
import 'package:typikon/pages/bible_chapter_page.dart';

// Меню выделения стиха главы Библии. Пункт «В других изданиях» собирается той
// же функцией, что страница главы, — иначе тест проверял бы копию и разошёлся
// бы с экраном молча.

const String verse = "Исповемся Тебе, Господи, всем сердцем моим";

class CapturedRoute {
  String? name;
  Object? arguments;
}

Future<CapturedRoute> pumpVerse(WidgetTester tester) async {
  final captured = CapturedRoute();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => SelectionMenu.wordsOnly(
          containers: const [
            TextContainer.verse(chapter: 9, verse: 13, text: verse),
          ],
          extraItems: (phrase, container) =>
              bibleVerseMenuItems(context, "psaltir", phrase, container),
          child: const Center(child: Text(verse)),
        ),
      ),
    ),
    onGenerateRoute: (settings) {
      captured
        ..name = settings.name
        ..arguments = settings.arguments;
      return MaterialPageRoute(builder: (_) => const Scaffold(body: Text("согласование")));
    },
  ));
  return captured;
}

Future<void> selectWord(WidgetTester tester) async {
  await tester.longPress(find.text(verse));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("долгое нажатие по стиху даёт пункт «В других изданиях»", (tester) async {
    await pumpVerse(tester);
    await selectWord(tester);

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text("В других изданиях"), findsOneWidget);
  });

  testWidgets("тап по пункту уходит на /concordance с каноническим адресом",
      (tester) async {
    final captured = await pumpVerse(tester);
    await selectWord(tester);

    await tester.tap(find.text("В других изданиях"));
    await tester.pumpAndSettle();

    expect(captured.name, "/concordance");
    expect(captured.arguments, "psaltir.9.13");
  });

  testWidgets("выделение вне стиха пункта не даёт", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SelectionMenu.wordsOnly(
            // Контейнер не содержит выделяемый текст: совпадения нет, и пункт
            // обязан пропасть — иначе адрес собрался бы на пустом месте.
            containers: const [
              TextContainer.verse(chapter: 1, verse: 1, text: "В начале сотвори Бог"),
            ],
            extraItems: (phrase, container) =>
                bibleVerseMenuItems(context, "psaltir", phrase, container),
            child: const Center(child: Text(verse)),
          ),
        ),
      ),
    ));
    await selectWord(tester);

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text("В других изданиях"), findsNothing);
  });
}
