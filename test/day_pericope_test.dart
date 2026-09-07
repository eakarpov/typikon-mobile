import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/day.dart';
import 'package:typikon/utils/pericope_route.dart';

/// Урезанный ответ /api/v1/days/:id — важно, что Евангелие и Апостол приходят
/// зачалом (текста нет, вместо него заглушка), а Устав ставит их на каждый день.
const String _dayJson = '''
{
  "id": "698b93b9bfe4062054859ceb",
  "name": "Понедельник 2-й седмицы по Пятидесятнице",
  "kathisma1": {"items": [{"cite": "", "text": {"_id": "67d2", "name": "Беседа", "content": "текст", "csSource": true}}]},
  "gospelMatins": {"items": null},
  "gospelLiturgy": {"items": [{
    "cite": "", "description": "Мф. 19", "pericopeId": "6a82", "text": {"_id": null},
    "pericope": {
      "id": "6a82", "source": "gospel", "label": "Мф. 19", "textId": "6a8205bc", "textName": "От Матфея",
      "ranges": [
        {"chapterFrom": 6, "verseFrom": 31, "chapterTo": 6, "verseTo": 34},
        {"chapterFrom": 7, "verseFrom": 9, "chapterTo": 7, "verseTo": 11}
      ],
      "verses": [{"chapter": 6, "verse": 31, "content": "Не пецытеся"}]
    }
  }]},
  "apostleLiturgy": {"items": [{
    "cite": "", "description": "Рим. 83", "text": {"_id": null},
    "pericope": {
      "id": "6a83", "source": "apostle", "label": "Рим. 83", "textId": "6a8206", "textName": "К Римлянам",
      "ranges": [{"chapterFrom": 2, "verseFrom": 28, "chapterTo": 3, "verseTo": 18}],
      "verses": []
    }
  }]}
}
''';

void main() {
  group('DayTexts', () {
    final day = DayTexts.fromJson(jsonDecode(_dayJson));

    test('поднимает Евангелие и Апостол на Литургии', () {
      expect(day.gospelLiturgy?.items, isNotEmpty);
      expect(day.apostleLiturgy?.items, isNotEmpty);
      expect(day.gospelLiturgy!.items!.first.pericope!.label, "Мф. 19");
      expect(day.apostleLiturgy!.items!.first.pericope!.label, "Рим. 83");
    });

    test('заглушка {"_id": null} не считается текстом', () {
      final gospel = day.gospelLiturgy!.items!.first;
      expect(gospel.text, isNull);
      expect(gospel.isPericope, isTrue);
      expect(day.kathisma1!.items!.first.text, isNotNull);
      expect(day.kathisma1!.items!.first.isPericope, isFalse);
    });

    test('пустой слот остаётся пустым, а не падает', () {
      expect(day.gospelMatins?.items, isEmpty);
      expect(day.panagia, isNull);
    });

    test('разбирает границы зачала', () {
      final ranges = day.gospelLiturgy!.items!.first.pericope!.ranges;
      expect(ranges.length, 2);
      expect(ranges.first.contains(6, 31), isTrue);
      expect(ranges.first.contains(6, 35), isFalse);
      expect(ranges.last.contains(7, 10), isTrue);
    });

    test('зачало через границу главы включает стихи обеих', () {
      final range = day.apostleLiturgy!.items!.first.pericope!.ranges.single;
      expect(range.contains(2, 29), isTrue);
      expect(range.contains(3, 1), isTrue);
      expect(range.contains(3, 19), isFalse);
      expect(range.contains(2, 27), isFalse);
    });
  });

  group('аргумент маршрута /reading', () {
    test('без границ остаётся голым id', () {
      expect(readingRouteArgument("abc"), "abc");
    });

    test('кодирует и разбирает границы обратно', () {
      final day = DayTexts.fromJson(jsonDecode(_dayJson));
      final pericope = day.gospelLiturgy!.items!.first.pericope!;
      final argument = readingRouteArgument(pericope.textId!, ranges: pericope.ranges);
      expect(argument, "6a8205bc#6:31-6:34,7:9-7:11");

      final target = parseReadingArgument(argument);
      expect(target.textId, "6a8205bc");
      expect(target.ranges.length, 2);
      expect(target.anchorChapter, 6);
      expect(target.contains(6, 33), isTrue);
      expect(target.contains(7, 1), isFalse);
      expect(target.rangesLabel, "гл. 6, ст. 31–34; гл. 7, ст. 9–11");
    });

    test('понимает прежний формат с одной главой', () {
      final target = parseReadingArgument("abc#12");
      expect(target.textId, "abc");
      expect(target.ranges, isEmpty);
      expect(target.anchorChapter, 12);
    });

    test('мусор в суффиксе не мешает открыть текст', () {
      final target = parseReadingArgument("abc#:-:");
      expect(target.textId, "abc");
      expect(target.ranges, isEmpty);
      expect(target.anchorChapter, isNull);
    });
  });
}
