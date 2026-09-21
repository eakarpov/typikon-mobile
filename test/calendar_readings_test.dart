import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/calendar.dart';

/// Места службы приходят перечнем `readings`, а не полями по имени.
///
/// Вторая версия API не отдаёт ни `vigil`, ни `kathisma1`, ни прочих двадцати
/// полей — она присылает перечень разделов с их подписями. Главная и страница
/// дня переехали на него при переводе на v2, а калькулятор тогда пропустили, и
/// он показывал пустую страницу на любой день: поля были на месте ровно до тех
/// пор, пока сервер их присылал.
///
/// Образец — настоящий ответ сервера, ужатый до одного раздела.
void main() {
  CalendarDay live() => CalendarDay.fromJson(
        jsonDecode(File("test/fixtures/live_calendar.json").readAsStringSync()),
      );

  test("разделы читаются из readings", () {
    final day = live();

    expect(day.readings, isNotEmpty);
    expect(day.readings.first.title, isNotEmpty);
    expect(day.readings.first.items, isNotEmpty);
  });

  test("полей по имени сервер больше не шлёт — на них опираться нельзя", () {
    // Утверждение не о приложении, а об ответе: если поля вернутся, это надо
    // заметить, а не молча начать их читать снова.
    final day = live();

    expect(day.vigil, isNull);
    expect(day.kathisma1, isNull);
    expect(day.gospelLiturgy, isNull);
  });

  test("старый ответ из кэша всё ещё разбирается", () {
    // На диске сутками лежат ответы прежней версии — поля по имени. Запасной
    // разбор в DTO заведён ради них, и `readings` собирается и из них тоже,
    // так что страница не опустеет, пока кэш не протухнет.
    final cached = CalendarDay.fromJson({
      "day": {
        "name": "Вторник",
        "gospelLiturgy": {
          "items": [
            {"name": "Евангелие", "content": "Во время оно…"},
          ],
        },
      },
    });

    expect(cached.readings, isNotEmpty);
    expect(cached.readings.first.items, isNotEmpty);
  });

  test("имя дня и памяти на месте", () {
    final day = live();

    expect(day.name, isNotEmpty);
    expect(day.memories, isNotNull);
  });
}
