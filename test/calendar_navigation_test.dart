import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/calendar.dart';

/// По чтению с главной можно перейти.
///
/// Вторая версия API переименовала опознаватель текста: `_id` стал `id`. Здесь
/// это пропустили, и у обычного чтения `id` выходил пустым — плитка на главной
/// просто не нажималась. Зачала при этом переходили: они ведут не по `id`, а по
/// книге и границам, — и потому поломка выглядела выборочной.
///
/// Образец — настоящий ответ сервера.
void main() {
  CalendarDay live() => CalendarDay.fromJson(
        jsonDecode(File("test/fixtures/live_calendar.json").readAsStringSync()),
      );

  test("у обычного чтения есть, по чему перейти", () {
    final texts = live()
        .readings
        .expand((section) => section.items)
        .where((item) => !item.isPericope);

    expect(texts, isNotEmpty, reason: "в образце нет обычных чтений");
    for (final item in texts) {
      expect(item.id, isNotNull);
      expect(item.id, isNotEmpty);
    }
  });

  test("старое имя опознавателя всё ещё понимается", () {
    // В кэше сутки лежат ответы прежней версии.
    final cached = CalendarDay.fromJson({
      "day": {
        "readings": [
          {
            "slot": "vigil",
            "title": "На всенощном бдении",
            "items": [
              {"text": {"_id": "старый", "name": "Чтение"}},
            ],
          },
        ],
      },
    });

    expect(cached.readings.single.items.single.id, "старый");
  });

  test("у зачала опознавателя нет нарочно", () {
    // Он указывал бы на книгу Библии, которой в коллекции текстов больше нет,
    // — переход по нему уводил бы в пустой ответ.
    final pericopes =
        live().readings.expand((s) => s.items).where((i) => i.isPericope);

    for (final item in pericopes) {
      expect(item.id, isNull);
      expect(item.bookSlug, isNotNull);
    }
  });
}
