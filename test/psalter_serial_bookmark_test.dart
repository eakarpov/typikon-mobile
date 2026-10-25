import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/psalter_serial_bookmark.dart';
import 'package:typikon/store/reading_progress.dart';

// Закладка «Псалтирь подряд» — единственное, что помнит место между
// запусками. Испортится запись — и чтение откроется на чужом псалме.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'закладка появляется на главной и пропадает при сбросе, включая псалом 151',
    () async {
      await savePsalterSerialBookmark(151, 3);
      final entries = await getAllReadingProgress();
      expect(entries.single.id, 'psalter:serial');
      expect(entries.single.progress.name, contains('псалом 151, стих 3'));
      expect((await getPsalterSerialBookmark())?.verse, 3);
      await clearPsalterSerialBookmark();
      expect(await getAllReadingProgress(), isEmpty);
    },
  );

  test('прежняя закладка без времени тоже появляется на главной', () async {
    SharedPreferences.setMockInitialValues({
      'psalter:serial': '{"chapter":43,"verse":5}',
    });
    expect((await getAllReadingProgress()).single.id, 'psalter:serial');
  });

  test("пока «Подряд» не открывали, закладки нет", () async {
    expect(await getPsalterSerialBookmark(), isNull);
  });

  test("место запоминается и читается обратно", () async {
    await savePsalterSerialBookmark(43, 5);

    final saved = await getPsalterSerialBookmark();
    expect(saved?.chapter, 43);
    expect(saved?.verse, 5);
  });

  test("закладка одна: новое место вытесняет прежнее", () async {
    await savePsalterSerialBookmark(43, 5);
    await savePsalterSerialBookmark(118, 72);

    final saved = await getPsalterSerialBookmark();
    expect(saved?.chapter, 118);
    expect(saved?.verse, 72);
  });

  test("закладку можно снять", () async {
    await savePsalterSerialBookmark(43, 5);
    await clearPsalterSerialBookmark();

    expect(await getPsalterSerialBookmark(), isNull);
  });

  group("порченая запись не показывает чужое место", () {
    test("не json", () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        "psalter:serial": "мусор",
      });

      expect(await getPsalterSerialBookmark(), isNull);
    });

    test("json без нужных полей", () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        "psalter:serial": '{"chapter": 3}',
      });

      expect(await getPsalterSerialBookmark(), isNull);
    });

    test("поля не числом", () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        "psalter:serial": '{"chapter": "43", "verse": 5}',
      });

      expect(await getPsalterSerialBookmark(), isNull);
    });

    test("нулевые и отрицательные не берём", () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        "psalter:serial": '{"chapter": 0, "verse": 5}',
      });
      expect(await getPsalterSerialBookmark(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        "psalter:serial": '{"chapter": 3, "verse": -1}',
      });
      expect(await getPsalterSerialBookmark(), isNull);
    });
  });

  group("бессмысленное не пишется", () {
    test("глава меньше первой или стих меньше первого", () async {
      await savePsalterSerialBookmark(0, 5);
      expect(await getPsalterSerialBookmark(), isNull);

      await savePsalterSerialBookmark(3, 0);
      expect(await getPsalterSerialBookmark(), isNull);
    });

    test("негодная запись не затирает годную", () async {
      await savePsalterSerialBookmark(43, 5);
      await savePsalterSerialBookmark(-1, 0);

      final saved = await getPsalterSerialBookmark();
      expect(saved?.chapter, 43);
      expect(saved?.verse, 5);
    });
  });
}
