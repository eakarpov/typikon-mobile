import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/utils/text_search.dart';

// Поиск внутри открытого текста: сверяется без ударений и регистра, а диапазоны
// возвращаются в исходной строке — по ним красят то, что видит читатель.

void main() {
  group("базовый поиск", () {
    test("находит без ударений в запросе, отвечает с ударениями", () {
      // «Госпо́дь»: о + комбинирующая оксия — снятие знака сдвигает смещения,
      // и возвращённый диапазон обязан вести в ИСХОДНУЮ строку. Конец берётся
      // по началу следующей буквы, поэтому знак после «о» входит в отрезок.
      final matches = searchParagraphs(["Госпо́дь благословен"], "Господь");

      expect(matches.keys, [0]);
      expect(matches[0], [(0, 8)]);
      expect("Госпо́дь благословен".substring(0, 8), "Госпо́дь");
    });

    test("регистр не различается", () {
      final matches = searchParagraphs(["Господь БЛАГОСЛОВЕН"], "господь");

      expect(matches[0], [(0, 7)]);
    });

    test("верхний регистр запроса тоже находит", () {
      final matches = searchParagraphs(["Господь благословен"], "ГОСПОДЬ");

      expect(matches[0], [(0, 7)]);
    });

    test("несколько вхождений и несколько абзацев", () {
      final matches = searchParagraphs([
        "Господь дал знак. Господь сказал.",
        "Ничего здесь.",
        "Помяни Господь.",
      ], "господь");

      expect(matches.length, 2);
      expect(matches[0], [(0, 7), (18, 25)]);
      expect(matches[2], [(7, 14)]);
    });

    test("абзацы без совпадений в карту не попадают", () {
      final matches = searchParagraphs(["В начале", "бытия"], "неттакого");

      expect(matches, isEmpty);
    });
  });

  group("короткие запросы", () {
    test("пустой запрос не ищется", () {
      expect(searchParagraphs(["Господь"], ""), isEmpty);
      expect(searchParagraphs(["Господь"], "   "), isEmpty);
    });

    test("одиночный знак не ищется", () {
      expect(searchParagraphs(["Господь"], "г"), isEmpty);
    });

    test("одни ударения — не запрос", () {
      // Снятие знаков не должно превращать «́́» в двухзначный запрос.
      expect(searchParagraphs(["Госпо́дь"], "о́"), isEmpty);
    });
  });

  group("потолок совпадений", () {
    test("больше лимита не собирается", () {
      final paragraphs = List.filled(600, "Господь благословен", growable: false);
      final matches = searchParagraphs(paragraphs, "господь");
      final total = flattenSearchMatches(matches).length;

      expect(total, searchMatchLimit);
    });
  });

  group("плоский список", () {
    test("идёт по порядку абзацев и вхождений", () {
      final matches = searchParagraphs(["Авва Авва", "Авва"], "авва");
      final flat = flattenSearchMatches(matches);

      expect(flat, [(0, 4), (5, 9), (0, 4)]);
    });
  });
}
