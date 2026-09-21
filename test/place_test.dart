import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/place.dart';
import 'package:typikon/dto/place_mentions.dart';

// Разбор мест. Записи заводились руками и тремя импортами подряд: у пустыни
// Иорданской нет точки, у половины мест нет рода, у иных координаты до сих пор
// лежат строками. Строгий разбор ронял бы карточку целиком там, где не хватает
// одного поля, — и читатель видел бы не «неизвестно», а пустой экран.

const String jerusalem = '''
{
  "id": "6aa84ad368696c7af796cbef",
  "slug": "ierusalim",
  "alias": "ierusalim-old",
  "name": "Иерусалим",
  "description": "Град великого Царя.",
  "kind": "settlement",
  "status": "extant",
  "latitude": 31.7683,
  "longitude": 35.2137,
  "synonyms": ["Сион"],
  "links": [{"text": "Статья", "url": "https://example.org"}],
  "names": [
    {"name": "Иевус", "transliteration": "Jebus", "lang": "heb", "role": "biblical",
     "from": -1400, "to": -1000, "source": "openbible"},
    {"name": "Эль-Кудс", "lang": "ar", "role": "modern", "from": 638, "to": null,
     "source": "wikidata"}
  ],
  "periods": [{"label": "Второй Храм", "from": -516, "to": 70, "source": "pleiades"}],
  "externals": [{"source": "openbible", "id": "a1234"}, {"source": "nikifor", "id": "nikifor-ierusalim"}]
}
''';

void main() {
  group("карточка места", () {
    final place = PlaceDetail.fromJson(jsonDecode(jerusalem));

    test("имена по эпохам разбираются со своими годами", () {
      expect(place.names.length, 2);
      expect(place.names.first.name, "Иевус");
      expect(place.names.first.role, "biblical");
      // До Рождества Христова — отрицательные.
      expect(place.names.first.from, -1400);
      expect(place.names.last.to, isNull);
    });

    test("эпохи и внешние ключи не теряются", () {
      expect(place.periods.single.label, "Второй Храм");
      expect(place.externals.map((e) => e.source), ["openbible", "nikifor"]);
    });

    test("адрес для перехода — наш слуг, пока он есть", () {
      expect(place.address, "ierusalim");
    });
  });

  group("координаты", () {
    test("числом", () {
      final place = PlaceDetail.fromJson(jsonDecode(jerusalem));
      expect(place.latitude, 31.7683);
      expect(place.hasPoint, isTrue);
    });

    test("строкой — как их записывали руками", () {
      final place = PlaceDetail.fromJson(
          jsonDecode('{"id": "1", "name": "Ай", "latitude": "31.9", "longitude": "35.2"}'));

      expect(place.latitude, 31.9);
      expect(place.longitude, 35.2);
    });

    test("их может не быть вовсе, и это не поломка", () {
      // У пустыни Иорданской точки нет. Прежде здесь стоял double.parse, и
      // первое же такое место роняло карточку.
      final place = PlaceDetail.fromJson(
          jsonDecode('{"id": "1", "name": "Пустыня Иорданская"}'));

      expect(place.latitude, isNull);
      expect(place.hasPoint, isFalse);
    });
  });

  group("строка указателя", () {
    test("несёт счёт упоминаний в Писании", () {
      final row = PlaceSummary.fromJson(jsonDecode(
          '{"id": "1", "slug": "ierusalim", "name": "Иерусалим", "scripture": 896}'));

      expect(row.scripture, 896);
      expect(row.address, "ierusalim");
    });

    test("без слуга спрашивается по опознавателю", () {
      // В разметке текстов ключом стоит то опознаватель, то прежний псевдоним.
      final row = PlaceSummary.fromJson(jsonDecode('{"id": "6aa8", "name": "Ай"}'));

      expect(row.address, "6aa8");
      expect(row.scripture, 0);
    });
  });

  group("упоминания", () {
    test("книги Писания приходят числом стихов, а не стихами", () {
      final mentions = PlaceMentions.fromJson(jsonDecode('''
        {"scripture": {"total": 773, "pending": 102,
          "books": [{"canonId": "iisus-navin", "name": "Книга Иисуса Навина",
                     "abbr": "Нав", "verses": 8}]}}
      '''));

      expect(mentions.scripture.total, 773);
      expect(mentions.scripture.pending, 102);
      expect(mentions.scripture.books.single.verses, 8);
    });

    test("неподписанные песнопения видны как таковые", () {
      // Певческий корпус на сервере бывает недоступен, и тогда подписи строк
      // неизвестны. Сорок строк «песнопение» подряд читались бы как поломка.
      final mentions = PlaceMentions.fromJson(jsonDecode('''
        {"chants": {"total": 993, "shown": 1, "labelled": false,
          "items": [{"id": "84021", "unit": null, "memory": null, "context": "въ Ри́мѣ"}]}}
      '''));

      expect(mentions.chants.labelled, isFalse);
      expect(mentions.chants.total, 993);
      expect(mentions.chants.items.single.unit, isNull);
    });

    test("сосед без адреса не ведёт никуда", () {
      // Латинское имя значит скрытую страницу: показываем именем, но перехода
      // нет — он ответил бы «такого места нет».
      final mentions = PlaceMentions.fromJson(jsonDecode('''
        {"relations": [{"direction": "in", "type": "succeeds", "confidence": "certain",
          "other": {"id": "9", "slug": null, "name": "Ancyra"}}]}
      '''));

      final relation = mentions.relations.single;
      expect(relation.hasPage, isFalse);
      expect(relation.otherName, "Ancyra");
      expect(relation.direction, "in");
    });

    test("пустой ответ остаётся пустым, а не падает", () {
      // Место, о котором корпус пока ничего не знает, — обычное дело: таких
      // больше половины.
      final mentions = PlaceMentions.fromJson(jsonDecode("{}"));

      expect(mentions.isEmpty, isTrue);
      expect(mentions.scripture.books, isEmpty);
      expect(mentions.chants.labelled, isTrue, reason: "умолчание — подписи есть");
    });

    test("оговорка и ссылка на источники приходят с сервера", () {
      // Обе обязаны быть одинаковы во всех поверхностях, поэтому и приходят
      // строкой, а не пишутся здесь.
      final mentions = PlaceMentions.fromJson(jsonDecode(
          '{"saintsCaveat": "Место названо в чтениях", "attribution": "OpenBible…"}'));

      expect(mentions.saintsCaveat, isNotEmpty);
      expect(mentions.attribution, isNotEmpty);
    });
  });

  group("места текста и главы", () {
    test("статья о месте отличается от упоминания", () {
      final refs = [
        TextPlaceRef.fromJson(jsonDecode('{"id": "1", "slug": "ierusalim", "name": "Иерусалим", "subject": true}')),
        TextPlaceRef.fromJson(jsonDecode('{"id": "2", "slug": "gay", "name": "Гай"}')),
      ];

      expect(refs.first.subject, isTrue);
      expect(refs.last.subject, isFalse);
    });

    test("место главы несёт номера стихов", () {
      final place = ChapterPlace.fromJson(
          jsonDecode('{"id": "1", "slug": "gavaon", "name": "Гаваон", "verses": [1, 2, 4]}'));

      expect(place.verses, [1, 2, 4]);
      expect(place.hasPage, isTrue);
    });

    test("место главы без страницы не ведёт никуда", () {
      final place = ChapterPlace.fromJson(
          jsonDecode('{"id": "1", "slug": null, "name": "Beth-arabah", "verses": [6]}'));

      expect(place.hasPage, isFalse);
    });
  });
}
