import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pericope.dart';
import 'package:typikon/utils/bible_route.dart';

// Аргумент маршрута /bible собирают из нескольких мест сразу, и ошибка в нём не
// заметна: экран откроется, просто не на том месте.

void main() {
  group("сборка и разбор", () {
    test("книга без главы открывается на первой", () {
      final target = parseBibleArgument("matfeya");

      expect(target.canonId, "matfeya");
      expect(target.chapter, 1);
      expect(target.ranges, isEmpty);
    });

    test("книга и глава ходят туда и обратно", () {
      final argument = bibleRouteArgument("matfeya", chapter: 19);

      expect(argument, "matfeya/19");
      final target = parseBibleArgument(argument);
      expect(target.canonId, "matfeya");
      expect(target.chapter, 19);
    });

    test("границы зачала кодируются и разбираются обратно", () {
      final ranges = [
        const PericopeRange(chapterFrom: 6, verseFrom: 31, chapterTo: 6, verseTo: 34),
        const PericopeRange(chapterFrom: 7, verseFrom: 9, chapterTo: 7, verseTo: 11),
      ];

      final argument = bibleRouteArgument("marka", chapter: 6, ranges: ranges);
      expect(argument, "marka/6#6:31-6:34,7:9-7:11");

      final target = parseBibleArgument(argument);
      expect(target.ranges.length, 2);
      expect(target.ranges.first.chapterFrom, 6);
      expect(target.ranges.last.verseTo, 11);
    });
  });

  group("уступки, перенесённые из /reading", () {
    test("глава берётся из границ зачала, а не из пути", () {
      // Зачало часто начинается не в той главе, которую подставил вызывающий:
      // иначе читатель попал бы в главу, где зачала ещё нет.
      final target = parseBibleArgument("marka/1#6:31-6:34");

      expect(target.chapter, 6);
    });

    test("неразобравшийся хвост открывает главу, а не роняет экран", () {
      // Открытая не на том месте глава лучше сообщения об ошибке.
      final target = parseBibleArgument("matfeya/19#мусор");

      expect(target.canonId, "matfeya");
      expect(target.chapter, 19);
      expect(target.ranges, isEmpty);
    });

    test("нечисловая глава не роняет разбор", () {
      expect(parseBibleArgument("matfeya/абв").chapter, 1);
    });
  });

  group("подпись и попадание в зачало", () {
    test("границы называются словами", () {
      final target = parseBibleArgument("marka/6#6:31-6:34,7:9-7:11");

      expect(target.rangesLabel, "гл. 6, ст. 31–34; гл. 7, ст. 9–11");
    });

    test("стих внутри зачала опознаётся, снаружи — нет", () {
      final target = parseBibleArgument("marka/6#6:31-6:34");

      expect(target.contains(6, 32), isTrue);
      expect(target.contains(6, 35), isFalse);
      expect(target.contains(7, 1), isFalse);
    });

    test("без границ ничего не подсвечивается", () {
      expect(parseBibleArgument("matfeya/19").contains(19, 1), isFalse);
    });
  });
}
