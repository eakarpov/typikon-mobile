import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/dto/concordance.dart';
import 'package:typikon/pages/concordance_page.dart';

// Экран «Стих в изданиях». Как и у страницы поиска, сетевой слой подменяется
// тестом через конструктор: иначе каждый тест ходил бы в сеть. Проверяем, что
// доходит главное — имена изданий и книг, сдвинутая нумерация как напечатано и
// канонический адрес в переходе к главе, а отказ «такого стиха нет» назван
// своим именем.

ConcordancePlace place(int chapter, int verse) =>
    ConcordancePlace(book: "psaltir", chapter: chapter, verse: verse);

Concordance sample() => Concordance(
      canonRef: "psaltir.9.13",
      editions: [
        ConcordanceEdition(
            edition: "cs-eliz", book: "psaltir", places: [place(9, 13)]),
        ConcordanceEdition(
            edition: "ro-1688", book: "psaltir", places: [place(9, 12)]),
      ],
    );

Future<BibleEditionList> editions() async => BibleEditionList([
      const BibleEdition(
          code: "cs-eliz",
          title: "Елизаветинская",
          shortTitle: "ЦС",
          language: "cu",
          languageCode: "cs",
          versification: "sla-lxx"),
      const BibleEdition(
          code: "ro-1688",
          title: "Сфънта Скриптура",
          shortTitle: "РУМ",
          language: "ro_cyr",
          languageCode: "ro",
          versification: "ro-1688"),
    ]);

Future<BibleBookList> books() async => BibleBookList([
      const BibleBook(
          id: "psaltir",
          name: "Псалтирь",
          abbr: "Пс",
          section: "teaching",
          inCanon: true,
          chapters: 151),
    ]);

class CapturedRoute {
  String? name;
  Object? arguments;
}

Future<CapturedRoute> pumpPage(
  WidgetTester tester, {
  required Future<Concordance> Function(String ref) concordance,
  Future<BibleEditionList> Function()? editionsFor,
  Future<BibleBookList> Function()? booksFor,
}) async {
  final captured = CapturedRoute();
  await tester.pumpWidget(MaterialApp(
    home: ConcordancePage(
      null,
      ref: "psaltir.9.13",
      concordance: concordance,
      editions: editionsFor ?? editions,
      books: booksFor ?? books,
    ),
    onGenerateRoute: (settings) {
      if (settings.name == Navigator.defaultRouteName) return null;
      captured
        ..name = settings.name
        ..arguments = settings.arguments;
      return MaterialPageRoute(builder: (_) => const Scaffold(body: Text("глава")));
    },
  ));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets("имена изданий и книг доходят, места — как напечатано", (tester) async {
    await pumpPage(tester, concordance: (ref) async => sample());

    expect(find.text("Стих в изданиях: psaltir.9.13"), findsOneWidget);
    expect(find.text("Елизаветинская"), findsOneWidget);
    expect(find.text("Сфънта Скриптура"), findsOneWidget);
    // Каноническому 9:13 у румынского издания отвечает напечатанное 9:12.
    expect(find.text("Псалтирь 9:13"), findsOneWidget);
    expect(find.text("Псалтирь 9:12"), findsOneWidget);
  });

  testWidgets("незнакомые коды показываются как есть", (tester) async {
    await pumpPage(
      tester,
      concordance: (ref) async => sample(),
      editionsFor: () async => const BibleEditionList([]),
      booksFor: () async => const BibleBookList([]),
    );

    expect(find.text("ro-1688"), findsOneWidget);
    expect(find.text("psaltir 9:12"), findsOneWidget);
  });

  testWidgets("тап по месту открывает главу с канонической подсветкой", (tester) async {
    final captured = await pumpPage(tester, concordance: (ref) async => sample());

    // Место напечатано как 9:12, а маршрут и подсветка ждут канонический счёт:
    // выделить надо 9:13 — иначе подсветка встала бы на соседний стих.
    await tester.tap(find.text("Псалтирь 9:12"));
    await tester.pumpAndSettle();

    expect(captured.name, "/bible");
    expect(captured.arguments, "psaltir/9#9:13-9:13");
  });

  testWidgets("пустой список изданий — честный ответ, а не ошибка", (tester) async {
    await pumpPage(
      tester,
      concordance: (ref) async => const Concordance(canonRef: "psaltir.9.13", editions: []),
    );

    expect(find.text("Этот стих не печатает ни одно издание собрания."), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets("отказ 404 показывает сообщение сервера без «Повторить»", (tester) async {
    await pumpPage(
      tester,
      concordance: (ref) async =>
          throw ApiNotFoundException("Такого стиха нет ни в одном издании собрания"),
    );

    expect(find.textContaining("Такого стиха нет"), findsOneWidget);
    expect(find.text("Повторить"), findsNothing);
  });
}
