import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/calendar.dart';

// Календарь на переходе с движка устава на вторую версию API. Кэш дня живёт
// сутки, а прошедшие даты — годами: обе формы ответа будут встречаться ещё
// долго, и разбор обязан читать обе.

void main() {
  test("ответ второй версии читается списком мест службы", () {
    final day = CalendarDay.fromJson(jsonDecode('''
      {"date": "2026-09-08", "churchDate": "2026-08-26",
       "memories": {"primary": {"id": "1", "name": "Адриана и Наталии", "sign": "NO_SIGN"},
                    "secondary": []},
       "day": {"name": "Вторник пятнадцатой седмицы", "readings": [
         {"slot": "gospelLiturgy", "title": "Евангелие на Литургии",
          "items": [{"description": "Мк. 22", "text": null}]}
       ]}}
    '''));

    expect(day.name, "Вторник пятнадцатой седмицы");
    expect(day.readings.single.title, "Евангелие на Литургии");
    expect(day.readings.single.items.single.description, "Мк. 22");
    expect(day.memories.defaultMemory?.name, "Адриана и Наталии");
  });

  test("память зовётся primary во второй версии и default в движке устава", () {
    // Слово одно и то же — память, которой день назван.
    final engine = CalendarDay.fromJson(jsonDecode(
        '{"memories": {"default": {"id": "1", "name": "Адриана"}, "secondary": []}, "day": {}}'));

    expect(engine.memories.defaultMemory?.name, "Адриана");
  });

  test("ответ движка устава раскладывается по местам службы здесь", () {
    // У него места службы — поля по имени, и порядок с подписями приходится
    // знать самим: другого источника у такого ответа нет. Нужно это только
    // ради того, что уже лежит в кэше.
    final old = CalendarDay.fromJson(jsonDecode('''
      {"date": "2026-09-08",
       "memories": {"default": null, "secondary": []},
       "day": {"name": "Вторник",
               "gospelLiturgy": {"items": [{"description": "Мк. 22"}]},
               "apostleLiturgy": {"items": [{"description": "Гал. 200"}]},
               "h3": {"items": []}}}
    '''));

    // Порядок хода службы: Апостол прежде Евангелия, пустое место не показано.
    expect(old.readings.map((r) => r.slot), ["apostleLiturgy", "gospelLiturgy"]);
    expect(old.readings.first.title, "Апостол на Литургии");
  });

  test("день без чтений не роняет разбор", () {
    final bare = CalendarDay.fromJson(jsonDecode('{"memories": null, "day": null}'));

    expect(bare.readings, isEmpty);
    expect(bare.memories.isEmpty, isTrue);
    expect(bare.name, isEmpty);
  });
}
