import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/paged.dart';

// Конверт коллекции v2. Ошибка здесь не видна глазами: список просто не
// догрузится дальше первой страницы — или, наоборот, будет крутить запросы,
// которым сервер уже нечего вернуть.

Paged<int> parse(String body) =>
    Paged.fromJson<int>(jsonDecode(body), (item) => item["n"] as int);

void main() {
  test("конверт разбирается", () {
    final page = parse('{"items":[{"n":1},{"n":2}],"total":57,"limit":50,"offset":0}');

    expect(page.items, [1, 2]);
    expect(page.total, 57);
    expect(page.limit, 50);
    expect(page.offset, 0);
  });

  group("есть ли что просить дальше", () {
    test("первая страница из нескольких — есть", () {
      final page = parse('{"items":[{"n":1}],"total":10,"limit":1,"offset":0}');

      expect(page.hasMore, isTrue);
    });

    test("последняя страница — нет", () {
      // 0-я по 49-ю уже показаны, всего пятьдесят: просить нечего.
      final items = List.generate(20, (i) => '{"n":$i}').join(",");
      final page = parse('{"items":[$items],"total":50,"limit":20,"offset":30}');

      expect(page.offset + page.items.length, 50);
      expect(page.hasMore, isFalse);
    });

    test("сервер отдал меньше запрошенного — считаем по полученному", () {
      // Иначе счёт по limit перепрыгнул бы через хвост выдачи.
      final page = parse('{"items":[{"n":1},{"n":2}],"total":10,"limit":50,"offset":0}');

      expect(page.hasMore, isTrue);
    });

    test("пустая страница — конец, даже если total говорит иначе", () {
      // Без этого список крутил бы запросы до бесконечности.
      final page = parse('{"items":[],"total":100,"limit":50,"offset":50}');

      expect(page.hasMore, isFalse);
    });
  });

  group("порченый ответ не роняет разбор", () {
    test("не объект", () {
      expect(Paged.fromJson<int>(jsonDecode('[]'), (i) => 0).items, isEmpty);
    });

    test("items не список", () {
      expect(parse('{"items":"много","total":5}').items, isEmpty);
    });

    test("нет чисел — считаем нулями, а не падаем", () {
      final page = parse('{"items":[{"n":1}]}');

      expect(page.total, 0);
      expect(page.hasMore, isFalse);
    });
  });
}
