import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pericope.dart';
import 'package:typikon/dto/signs.dart';
import 'package:typikon/utils/pericope_route.dart';

void main() {
  group('SignsList', () {
    test('разбирает постраничный ответ сервера', () {
      final json = jsonDecode('''
        {"items": [
          {"month": 1, "date": 1, "name": "Обрезание Господне", "sign": "GREAT_VIGIL",
           "signConditional": false, "source": "typikon",
           "sourceUrl": "https://azbyka.ru/otechnik/x", "id": "6a83"}
        ], "total": 457, "page": 1, "pageSize": 20, "error": null}
      ''');
      final list = SignsList.fromJson(json);

      expect(list.list.length, 1);
      expect(list.total, 457);
      expect(list.hasMore, isTrue);
      // Раньше здесь читалось "_id", и id у каждой памяти был null.
      expect(list.list.first.id, "6a83");
      expect(list.list.first.sourceUrl, "https://azbyka.ru/otechnik/x");
    });

    test('последняя страница не просит продолжения', () {
      final list = SignsList.fromJson(jsonDecode(
        '{"items": [{"name": "a"}], "total": 41, "page": 3, "pageSize": 20}',
      ));
      expect(list.hasMore, isFalse);
    });

    test('принимает и голый список — прежнюю форму ответа', () {
      final list = SignsList.fromJson(jsonDecode('[{"name": "a", "id": "1"}]'));
      expect(list.list.length, 1);
      expect(list.total, 1);
      expect(list.hasMore, isFalse);
    });
  });

  group('splitVerseRuns', () {
    List<PericopeVerse> chapter(int number, int from, int to) => [
      for (var v = from; v <= to; v++)
        PericopeVerse(chapter: number, verse: v, content: "стих $number:$v"),
    ];

    test('без границ отдаёт всё одним куском', () {
      final runs = splitVerseRuns(chapter(6, 1, 5), const []);
      expect(runs.length, 1);
      expect(runs.single.inPericope, isFalse);
    });

    test('вырезает зачало из середины главы', () {
      final target = parseReadingArgument("a#6:3-6:4");
      final runs = splitVerseRuns(chapter(6, 1, 6), target.ranges);

      expect(runs.map((r) => r.inPericope).toList(), [false, true, false]);
      expect(runs[1].verses.map((v) => v.verse).toList(), [3, 4]);
    });

    test('зачало с начала главы не даёт пустого куска перед собой', () {
      final target = parseReadingArgument("a#6:1-6:2");
      final runs = splitVerseRuns(chapter(6, 1, 4), target.ranges);

      expect(runs.map((r) => r.inPericope).toList(), [true, false]);
      expect(runs.first.verses.map((v) => v.verse).toList(), [1, 2]);
    });

    test('разорванное зачало даёт два выделенных куска', () {
      final target = parseReadingArgument("a#6:2-6:3,6:5-6:6");
      final runs = splitVerseRuns(chapter(6, 1, 7), target.ranges);

      expect(runs.map((r) => r.inPericope).toList(), [false, true, false, true, false]);
      expect(runs.where((r) => r.inPericope).length, 2);
    });
  });
}
