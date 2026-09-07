import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/bible_bookmark.dart';

// Закладка — единственное, что помнит раздел Библии между запусками. Испортится
// запись — и оглавление либо покажет чужое место, либо промолчит о сохранённом.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("пока ничего не читали, закладки нет", () async {
    expect(await getBibleBookmark(), isNull);
  });

  test("место запоминается и читается обратно", () async {
    await saveBibleBookmark("matfeya", 19);

    final saved = await getBibleBookmark();
    expect(saved?.canonId, "matfeya");
    expect(saved?.chapter, 19);
  });

  test("закладка одна: новое место вытесняет прежнее", () async {
    // Закладка на книгу — это уже список «что я где читаю», то есть другая вещь.
    await saveBibleBookmark("matfeya", 19);
    await saveBibleBookmark("bytie", 1);

    final saved = await getBibleBookmark();
    expect(saved?.canonId, "bytie");
    expect(saved?.chapter, 1);
  });

  test("закладку можно снять", () async {
    await saveBibleBookmark("matfeya", 19);
    await clearBibleBookmark();

    expect(await getBibleBookmark(), isNull);
  });

  group("порченая запись не показывает чужое место", () {
    test("не json", () async {
      SharedPreferences.setMockInitialValues({"bible_bookmark": "мусор"});

      expect(await getBibleBookmark(), isNull);
    });

    test("json без нужных полей", () async {
      SharedPreferences.setMockInitialValues({"bible_bookmark": '{"chapter": 3}'});

      expect(await getBibleBookmark(), isNull);
    });

    test("глава не числом", () async {
      SharedPreferences.setMockInitialValues(
          {"bible_bookmark": '{"canonId": "matfeya", "chapter": "девятнадцать"}'});

      expect(await getBibleBookmark(), isNull);
    });

    test("глава нулевая или отрицательная", () async {
      SharedPreferences.setMockInitialValues(
          {"bible_bookmark": '{"canonId": "matfeya", "chapter": 0}'});

      expect(await getBibleBookmark(), isNull);
    });
  });

  group("бессмысленное не пишется", () {
    test("книга без идентификатора", () async {
      await saveBibleBookmark("", 3);

      expect(await getBibleBookmark(), isNull);
    });

    test("глава меньше первой", () async {
      await saveBibleBookmark("matfeya", 0);

      expect(await getBibleBookmark(), isNull);
    });

    test("негодная запись не затирает годную", () async {
      // Иначе одна случайная попытка стёрла бы место, куда читатель дошёл.
      await saveBibleBookmark("matfeya", 19);
      await saveBibleBookmark("", 0);

      expect((await getBibleBookmark())?.canonId, "matfeya");
    });
  });
}
