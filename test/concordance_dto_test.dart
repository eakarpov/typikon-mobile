import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/concordance.dart';

// Разбор ответа согласования нумераций. Суть фичи в одном числе: канонический
// Пс. 9:13 у румынской Псалтири 1688 года напечатан как 9:12 — разбор обязан
// донести именно его, а не схлопать до канонического.

// Настоящий ответ сервера на «psaltir.9.13»: десять изданий собрания.
Concordance live() => Concordance.fromJson(
    jsonDecode(File("test/fixtures/concordance_psaltir_9_13.json").readAsStringSync()));

void main() {
  group("живой ответ", () {
    test("канонический адрес читается из ответа", () {
      expect(live().canonRef, "psaltir.9.13");
    });

    test("каждое издание несёт свой код, книгу и места", () {
      final data = live();

      expect(data.editions, isNotEmpty);
      for (final edition in data.editions) {
        expect(edition.edition, isNotEmpty);
        expect(edition.book, isNotEmpty);
        expect(edition.places, isNotEmpty);
        for (final place in edition.places) {
          expect(place.book, isNotEmpty);
          expect(place.chapter, greaterThan(0));
          expect(place.verse, greaterThan(0));
        }
      }
    });

    test("сдвинутая нумерация доходит как напечатано, а не как канонически", () {
      // Ровно ради этого числа фича и заведена: по родному номеру стих ищут
      // в бумажной книге, и подменить его каноническим молча нельзя.
      final ro = live().editions.firstWhere((e) => e.edition == "ro-1688");

      expect(ro.places.single.chapter, 9);
      expect(ro.places.single.verse, 12);
    });

    test("эталонное издание держит каноническое место", () {
      final cs = live().editions.firstWhere((e) => e.edition == "cs-eliz");

      expect(cs.places.single.verse, 13);
    });
  });

  group("терпимый разбор", () {
    test("пустой ответ не роняет разбор", () {
      final data = Concordance.fromJson(jsonDecode("{}"));

      expect(data.canonRef, "");
      expect(data.editions, isEmpty);
    });

    test("место без номеров даёт нули, а не падение", () {
      final data = Concordance.fromJson(jsonDecode('''
        {"canonRef": "psaltir.9.13",
         "editions": [{"edition": "ro-1688", "book": "psaltir",
                        "places": [{"book": "psaltir"}]}]}
      '''));

      final place = data.editions.single.places.single;
      expect(place.book, "psaltir");
      expect(place.chapter, 0);
      expect(place.verse, 0);
    });

    test("числа строками разбираются, мусор — нулём", () {
      final data = Concordance.fromJson(jsonDecode('''
        {"canonRef": "psaltir.9.13",
         "editions": [{"edition": "ro-1688", "book": "psaltir",
                        "places": [{"book": "psaltir", "chapter": "9",
                                     "verse": "двенадцатый"}]}]}
      '''));

      final place = data.editions.single.places.single;
      expect(place.chapter, 9);
      expect(place.verse, 0);
    });

    test("издание без places остаётся в списке", () {
      // Пустой список мест — «не печатает», и сервер присылает такие издания
      // редко; пропасть из списка они не должны в любом случае.
      final data = Concordance.fromJson(jsonDecode('''
        {"canonRef": "psaltir.9.13",
         "editions": [{"edition": "zh-1910", "book": "psaltir"}]}
      '''));

      expect(data.editions.single.edition, "zh-1910");
      expect(data.editions.single.places, isEmpty);
    });

    test("editions не списком — пустой список, а не исключение", () {
      final data = Concordance.fromJson(jsonDecode('{"canonRef": "x.y.z", "editions": 5}'));

      expect(data.editions, isEmpty);
    });
  });
}
