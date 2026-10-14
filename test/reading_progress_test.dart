import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/store/reading_progress.dart';

// «Продолжить чтение»: имя текста живёт в записи прогресса, и перезапись без
// имени его не стирает — страница текста пишет прогресс чаще, чем узнаёт имя.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("имя пишется вместе с прогрессом", () async {
    await saveReadingProgress("t1", 0.5, name: "Житие преподобного");

    final saved = await getReadingProgress("t1");
    expect(saved, isNotNull);
    expect(saved!.fraction, 0.5);
    expect(saved.name, "Житие преподобного");
  });

  test("запись без имени не затирает сохранённое", () async {
    await saveReadingProgress("t1", 0.5, name: "Житие преподобного");
    await saveReadingProgress("t1", 0.7);

    final saved = await getReadingProgress("t1");
    expect(saved!.fraction, 0.7);
    expect(saved.name, "Житие преподобного");
  });

  group("старые записи без имени", () {
    test("читаются: имя просто null", () async {
      SharedPreferences.setMockInitialValues({
        "reading_progress": jsonEncode({
          "t1": {
            "fraction": 0.5,
            "updatedAt": 1700000000000,
          },
        }),
      });

      final saved = await getReadingProgress("t1");
      expect(saved, isNotNull);
      expect(saved!.name, isNull);
      expect(saved.fraction, 0.5);
    });

    test("попадают в общий список", () async {
      SharedPreferences.setMockInitialValues({
        "reading_progress": jsonEncode({
          "t1": {"fraction": 0.5, "updatedAt": 1700000000000},
        }),
      });

      final all = await getAllReadingProgress();
      expect(all.length, 1);
      expect(all.single.id, "t1");
      expect(all.single.progress.name, isNull);
    });

    test("запись со страницы без имени не стирает старое имя", () async {
      SharedPreferences.setMockInitialValues({
        "reading_progress": jsonEncode({
          "t1": {
            "fraction": 0.5,
            "updatedAt": 1700000000000,
            "name": "Житие",
          },
        }),
      });

      await saveReadingProgress("t1", 0.8);

      expect((await getReadingProgress("t1"))!.name, "Житие");
    });
  });

  group("общий список", () {
    test("сортировка по свежести, потолок списка", () async {
      final all = <String, dynamic>{};
      for (var i = 0; i < 60; i++) {
        all["t$i"] = {
          "fraction": 0.1,
          "updatedAt": 1700000000000 + i * 1000,
          "name": "Текст $i",
        };
      }
      SharedPreferences.setMockInitialValues({
        "reading_progress": jsonEncode(all),
      });

      final entries = await getAllReadingProgress();
      expect(entries.length, maxProgressEntries);
      // Свежайший — последний записанный (t59) — идёт первым.
      expect(entries.first.id, "t59");
      expect(entries.last.id, "t10");
    });

    test("порченая запись не роняет список", () async {
      SharedPreferences.setMockInitialValues({
        "reading_progress": jsonEncode({
          "t1": {"fraction": 0.5, "updatedAt": 1700000000000},
          "t2": "мусор",
          "t3": {"fraction": "много", "updatedAt": 1700000000000},
        }),
      });

      final entries = await getAllReadingProgress();
      expect(entries.map((e) => e.id), ["t1"]);
    });
  });

  test("прочитанное не запоминается, и прежняя запись снимается", () async {
    await saveReadingProgress("t1", 0.5, name: "Житие");
    await saveReadingProgress("t1", finishedFraction + 0.01);

    expect(await getReadingProgress("t1"), isNull);
  });
}
