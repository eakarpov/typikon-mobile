import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/calendar.dart';
import 'package:typikon/dto/day.dart';
import 'package:typikon/utils/bible_route.dart';
import 'package:typikon/utils/pericope_route.dart';

/// Урезанный ответ `/api/v2/days/{alias}?expand=content`. Важно, что места
/// службы приходят СПИСКОМ с готовыми подписями, а Евангелие и Апостол — зачалом
/// без текста.
const String _dayJson = '''
{
  "id": "698b93b9bfe4062054859ceb",
  "alias": "ponedelnik-2",
  "name": "Понедельник 2-й седмицы по Пятидесятнице",
  "readings": [
    {"slot": "kathisma1", "title": "По седальнах первой кафизмы", "items": [
      {"cite": null, "text": {"id": "67d2", "name": "Беседа", "content": "текст", "csSource": true}}
    ]},
    {"slot": "gospelMatins", "title": "Евангелие на утрени", "items": []},
    {"slot": "apostleLiturgy", "title": "Апостол на Литургии", "items": [{
      "cite": null, "description": "Рим. 83", "text": null,
      "pericope": {
        "id": "6a83", "source": "apostle", "label": "Рим. 83", "bookSlug": "k-rimlyanam",
        "textId": "6a8206", "textName": "К Римлянам",
        "ranges": [{"chapterFrom": 2, "verseFrom": 28, "chapterTo": 3, "verseTo": 18}],
        "verses": []
      }
    }]},
    {"slot": "gospelLiturgy", "title": "Евангелие на Литургии", "items": [{
      "cite": null, "description": "Мф. 19", "text": null,
      "pericope": {
        "id": "6a82", "source": "gospel", "label": "Мф. 19", "bookSlug": "matfeya",
        "textId": "6a8205bc", "textName": "От Матфея",
        "ranges": [
          {"chapterFrom": 6, "verseFrom": 31, "chapterTo": 6, "verseTo": 34},
          {"chapterFrom": 7, "verseFrom": 9, "chapterTo": 7, "verseTo": 11}
        ],
        "verses": [{"chapter": 6, "verse": 31, "content": "Не пецытеся"}]
      }
    }]}
  ]
}
''';

void main() {
  group('DayTexts', () {
    final day = DayTexts.fromJson(jsonDecode(_dayJson));

    DayTextsPart first(String slot) =>
        day.readings.firstWhere((r) => r.slot == slot).items.first;

    test('подписи мест службы приходят с сервера, а не сочиняются здесь', () {
      // Прежде этот список был зашит в экране дня, и второй такой же жил на
      // сервере; разойдясь, они отняли у Великого пятка два чтения.
      expect(day.readings.map((r) => r.title),
          contains("Евангелие на Литургии"));
      expect(day.readings.map((r) => r.slot),
          containsAllInOrder(["kathisma1", "apostleLiturgy", "gospelLiturgy"]));
    });

    test('поднимает Евангелие и Апостол на Литургии', () {
      expect(first("gospelLiturgy").pericope!.label, "Мф. 19");
      expect(first("apostleLiturgy").pericope!.label, "Рим. 83");
    });

    test('зачало без текста текстом не считается', () {
      final gospel = first("gospelLiturgy");
      expect(gospel.text, isNull);
      expect(gospel.isPericope, isTrue);
      expect(first("kathisma1").text, isNotNull);
      expect(first("kathisma1").isPericope, isFalse);
    });

    test('тело текста приходит по просьбе и доходит до разбора', () {
      // Без `expand=content` его нет вовсе, и экран дня показал бы пустые
      // заголовки вместо чтений.
      expect(first("kathisma1").text!.content, "текст");
    });

    test('пустое место службы остаётся пустым, а не падает', () {
      expect(day.readings.firstWhere((r) => r.slot == "gospelMatins").items, isEmpty);
      expect(day.readings.where((r) => r.slot == "panagia"), isEmpty);
    });

    test('разбирает границы зачала', () {
      final ranges = first("gospelLiturgy").pericope!.ranges;
      expect(ranges.length, 2);
      expect(ranges.first.contains(6, 31), isTrue);
      expect(ranges.first.contains(6, 35), isFalse);
      expect(ranges.last.contains(7, 10), isTrue);
    });

    test('зачало через границу главы включает стихи обеих', () {
      final range = first("apostleLiturgy").pericope!.ranges.single;
      expect(range.contains(2, 29), isTrue);
      expect(range.contains(3, 1), isTrue);
      expect(range.contains(3, 19), isFalse);
      expect(range.contains(2, 27), isFalse);
    });
  });

  group('аргумент маршрута /reading', () {
    // Хвост за решёткой нёс главу или границы зачала — всё это относилось к
    // Библии, а она с 2.1 живёт своим разделом. Разбирать хвост всё равно
    // приходится: он остался в старых заметках и будет приходить ещё долго.
    test('голый идентификатор проходит как есть', () {
      expect(readingTextId("abc"), "abc");
    });

    test('прежний хвост с главой отбрасывается, а не роняет экран', () {
      expect(readingTextId("abc#12"), "abc");
    });

    test('прежний хвост с границами зачала отбрасывается тоже', () {
      expect(readingTextId("6a8205bc#6:31-6:34,7:9-7:11"), "6a8205bc");
    });

    test('мусор в суффиксе не мешает открыть текст', () {
      expect(readingTextId("abc#:-:"), "abc");
    });
  });

  group('дорога в раздел Библии', () {
    final day = DayTexts.fromJson(jsonDecode(_dayJson));

    test('зачало несёт книгу канона, а не только книгу издания', () {
      // По bookSlug открывается глава. textId с переездом Библии указывает на
      // bible_books, и открывать по нему нельзя: /api/v1/texts/{id} отвечает на
      // него двумястами с пустым телом.
      final pericope = day.readings
          .firstWhere((r) => r.slot == "gospelLiturgy").items.first.pericope!;

      expect(pericope.bookSlug, "matfeya");
    });

    test('из зачала собирается адрес главы с подсветкой', () {
      final pericope = day.readings
          .firstWhere((r) => r.slot == "gospelLiturgy").items.first.pericope!;
      final argument = bibleRouteArgument(
        pericope.bookSlug!,
        chapter: pericope.ranges.first.chapterFrom,
        ranges: pericope.ranges,
      );

      expect(argument, "matfeya/6#6:31-6:34,7:9-7:11");

      final target = parseBibleArgument(argument);
      expect(target.canonId, "matfeya");
      expect(target.chapter, 6);
      expect(target.contains(6, 33), isTrue);
      expect(target.contains(7, 1), isFalse);
    });

    test('зачало без книги канона кнопку не показывает', () {
      // Дневные ответы лежат в кэше сутками: ответ, отданный до появления
      // bookSlug, не должен уводить в ошибку.
      final pericope = Pericope.fromJson({
        "id": "x", "source": "gospel", "label": "Мф. 19",
        "ranges": [{"chapterFrom": 6, "verseFrom": 31, "chapterTo": 6, "verseTo": 34}],
      })!;

      expect(pericope.bookSlug, isNull);
    });
  });

  test('идентификатор зачала не подставляется в id дневного слота', () {
    // Прежде здесь стоял pericope.textId, и по нему предзагрузчик заранее качал
    // тексты дня — то есть складывал в кэш пустые ответы.
    final calendar = CalendarDayPartItem.fromJson(jsonDecode('''
      {"cite": "", "description": "Мф. 19", "pericope": {
        "id": "6a82", "label": "Мф. 19", "bookSlug": "matfeya", "textId": "6a8205bc",
        "ranges": [], "verses": []}}
    '''));

    expect(calendar.isPericope, isTrue);
    expect(calendar.bookSlug, "matfeya");
    expect(calendar.id, isNull);
  });
}
