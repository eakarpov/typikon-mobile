import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/bible.dart';

// Разбор ответов Библии. Опасное место здесь ровно одно, и оно молчаливое:
// пустая ячейка в строке значит «издание этого стиха не печатает». Схлопни её —
// и вся колонка съедет на строку вниз, экран при этом останется правдоподобным,
// а заметит подмену только тот, кто читает оба столбца сразу.

// Настоящий ответ сервера, урезанный до трёх строк: Пс. 9 в славянском и
// румынском изданиях. Надписания псалма румынское издание не печатает (первая
// строка), а дальше вся глава у него идёт со сдвинутым на единицу номером.
const String psalm9 = '''
{
  "book": {"id": "psaltir", "name": "Псалтирь", "abbr": "Пс", "section": "teaching", "inCanon": true},
  "chapter": 9,
  "editions": [
    {"code": "cs-eliz", "title": "Елизаветинская", "shortTitle": "ЦС", "language": "cu",
     "languageCode": "cs", "versification": "sla-lxx", "year": 1751, "sourceUrl": null},
    {"code": "ro-1688", "title": "Сфънта Скриптура", "shortTitle": "РУМ", "language": "ro_cyr",
     "languageCode": "ro", "versification": "ro-1688", "year": 1688, "sourceUrl": null}
  ],
  "verses": [
    {"canonRef": "psaltir.9.1", "verse": 1, "editions": [
      {"id": "a1", "canonRef": "psaltir.9.1", "chapter": 9, "verse": 1,
       "editionChapter": 9, "editionVerse": 1, "content": "Въ коне́цъ"},
      null
    ]},
    {"canonRef": "psaltir.9.2", "verse": 2, "editions": [
      {"id": "a2", "canonRef": "psaltir.9.2", "chapter": 9, "verse": 2,
       "editionChapter": 9, "editionVerse": 2, "content": "И҆сповѣ́мсѧ"},
      {"id": "b2", "canonRef": "psaltir.9.2", "chapter": 9, "verse": 2,
       "editionChapter": 9, "editionVerse": 1, "content": "Мърꙋрисиве"}
    ]},
    {"canonRef": "psaltir.9.3", "verse": 3, "editions": [
      {"id": "a3", "canonRef": "psaltir.9.3", "chapter": 9, "verse": 3,
       "editionChapter": 9, "editionVerse": 3, "content": "Возвеселю́сѧ"},
      {"id": "b3", "canonRef": "psaltir.9.3", "chapter": 9, "verse": 3,
       "editionChapter": 9, "editionVerse": 2, "content": "Веселиме"}
    ]}
  ]
}
''';

BibleChapter chapter() => BibleChapter.fromJson(jsonDecode(psalm9));

void main() {
  group("глава", () {
    test("книга и номер главы читаются из ответа", () {
      final data = chapter();

      expect(data.book.id, "psaltir");
      expect(data.book.name, "Псалтирь");
      expect(data.book.inCanon, isTrue);
      expect(data.chapter, 9);
    });

    test("издания идут в том же порядке, что и ячейки в строках", () {
      final data = chapter();

      expect(data.editions.map((e) => e.code), ["cs-eliz", "ro-1688"]);
      expect(data.rows.first.cells.length, data.editions.length);
    });

    test("непечатаемый стих остаётся пустой ячейкой, а не исчезает", () {
      // Ровно та ошибка, ради которой этот тест и написан: убери null — и
      // румынская колонка поедет на строку вверх, начиная с надписания псалма.
      final row = chapter().rows.first;

      expect(row.cells.length, 2);
      expect(row.cells[0], isNotNull);
      expect(row.cells[1], isNull);
    });

    test("строки не теряются и идут по каноническому номеру", () {
      final data = chapter();

      expect(data.rows.map((row) => row.verse), [1, 2, 3]);
      expect(data.rows.map((row) => row.canonRef).last, "psaltir.9.3");
    });
  });

  group("нумерация стиха", () {
    test("совпавшая нумерация сдвигом не считается", () {
      final cell = chapter().rows[1].cells[0]!;

      expect(cell.chapter, 9);
      expect(cell.verse, 2);
      expect(cell.shifted, isFalse);
    });

    test("разошедшийся родной номер помечается сдвигом", () {
      // По родному номеру стих ищут в бумажной книге, и подменить его
      // каноническим молча нельзя.
      final cell = chapter().rows[1].cells[1]!;

      expect(cell.verse, 2, reason: "каноническая нумерация");
      expect(cell.editionVerse, 1, reason: "как напечатано в издании");
      expect(cell.shifted, isTrue);
    });
  });

  group("колонка одного издания", () {
    test("пустые ячейки в одиночном виде отбрасываются", () {
      // В сплошном тексте одного издания показывать «стиха нет» нечего: это
      // правда только для одиночного вида, в параллельном пропуск обязан быть виден.
      final verses = chapter().versesFor(1);

      expect(verses.length, 2);
      expect(verses.map((v) => v.verse), [2, 3]);
    });

    test("колонка эталона отдаётся целиком и по порядку", () {
      final verses = chapter().versesFor(0);

      expect(verses.map((v) => v.verse), [1, 2, 3]);
      expect(verses.first.content, "Въ коне́цъ");
    });

    test("несуществующая колонка не роняет разбор", () {
      expect(chapter().versesFor(5), isEmpty);
      expect(chapter().versesFor(-1), isEmpty);
    });
  });

  group("издания", () {
    test("эталон узнаётся по нумерации, а не по коду", () {
      // Зашить 'cs-eliz' значило бы завести шестую копию списка изданий.
      final editions = chapter().editions;

      expect(editions[0].isReference, isTrue);
      expect(editions[1].isReference, isFalse);
    });

    test("конверт коллекции разбирается", () {
      final list = BibleEditionList.fromJson(jsonDecode(
          '{"items":[{"code":"cs-eliz","versification":"sla-lxx"}],"total":1,"limit":1,"offset":0}'));

      expect(list.list.single.code, "cs-eliz");
    });

    test("ответ без items не роняет разбор", () {
      expect(BibleEditionList.fromJson(jsonDecode('{"total":0}')).list, isEmpty);
    });
  });

  group("оглавление", () {
    final books = BibleBookList.fromJson(jsonDecode('''
      {"items": [
        {"id": "bytie", "name": "Бытие", "abbr": "Быт", "section": "pentateuch",
         "inCanon": true, "chapters": 50},
        {"id": "enokha", "name": "Книга Еноха", "abbr": "Ен", "section": "appendix",
         "inCanon": false, "chapters": null, "note": "в славянском каноне её нет"}
      ], "total": 2, "limit": 2, "offset": 0}
    '''));

    test("книги канона и приложения различаются признаком", () {
      expect(books.list.length, 2);
      expect(books.canon.map((book) => book.id), ["bytie"]);
    });

    test("у книги канона есть число глав, у приложения его нет", () {
      // null — «мы не считали»; ноль сказал бы «глав нет», и это была бы неправда.
      expect(books.byId("bytie")?.chapters, 50);
      expect(books.byId("enokha")?.chapters, isNull);
    });

    test("книга вне канона несёт пояснение, книга канона — нет", () {
      expect(books.byId("enokha")?.note, isNotNull);
      expect(books.byId("bytie")?.note, isNull);
    });

    test("незнакомая книга ищется без падения", () {
      expect(books.byId("otkuda-to"), isNull);
    });
  });
}
