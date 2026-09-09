import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/calendar.dart';
import 'package:typikon/utils/day_reading_reminders.dart';

// Ворота уведомления о чтениях дня. Ошибка в них либо будит человека ночью, либо
// повторяет одно и то же несколько раз за утро — заметить это можно только на
// себе, и потому проверяется оно здесь.

CalendarDay day({String memory = "Успение Пресвятой Богородицы", int places = 2}) =>
    CalendarDay.fromJson(jsonDecode('''
      {"memories": {"primary": {"id": "1", "name": "$memory"}, "secondary": []},
       "day": {"name": "Вторник пятнадцатой седмицы", "alias": "uspenie", "readings": [
         ${List.generate(places, (i) => '{"slot":"s$i","title":"т","items":[{"description":"Мк."}]}').join(",")}
       ]}}
    '''));

void main() {
  final noon = DateTime(2026, 9, 9, 12);

  test("говорит в назначенный час", () {
    final notice = readingVerdict(
        hour: 12, day: day(), lastNotifiedDate: null, now: noon);

    expect(notice.shows, isTrue);
    expect(notice.body, contains("Успение"));
    expect(notice.body, contains("чтений: 2"));
    expect(notice.payload, "reading:uspenie");
  });

  test("до назначенного часа молчит", () {
    // Уведомление о чтениях в три ночи хуже, чем не пришедшее вовсе.
    expect(readingVerdict(
        hour: 12, day: day(), lastNotifiedDate: null,
        now: DateTime(2026, 9, 9, 3)).shows, isFalse);
  });

  test("окно в два часа, а дальше не вовремя, а невпопад", () {
    // Фоновая задача просыпается, когда система даст окно, и в минуту не
    // попадает; но и в девять вечера «чтения дня» уже ни к чему.
    expect(readingVerdict(hour: 12, day: day(), lastNotifiedDate: null,
        now: DateTime(2026, 9, 9, 13)).shows, isTrue);
    expect(readingVerdict(hour: 12, day: day(), lastNotifiedDate: null,
        now: DateTime(2026, 9, 9, 14)).shows, isFalse);
  });

  test("дважды за день не говорит", () {
    expect(readingVerdict(hour: 12, day: day(), lastNotifiedDate: "2026-09-09",
        now: noon).shows, isFalse);
  });

  test("час не выбран — молчим", () {
    expect(readingVerdict(hour: null, day: day(), lastNotifiedDate: null, now: noon).shows,
        isFalse);
  });

  test("дня нет — молчим, а не обещаем пустоту", () {
    // Сети не было или служба устава молчит. Сказать «чтения готовы» и открыть
    // пустой экран хуже молчания.
    expect(readingVerdict(hour: 12, day: null, lastNotifiedDate: null, now: noon).shows,
        isFalse);
  });

  test("без памяти дня говорит именем дня", () {
    // У рядового дня памяти может не быть вовсе, и имя дня — всё, что есть.
    final notice = readingVerdict(
        hour: 12, day: day(memory: ""), lastNotifiedDate: null, now: noon);

    expect(notice.shows, isTrue);
    expect(notice.body, contains("Вторник"));
  });

  test("без чтений счёт не приписывается", () {
    final notice = readingVerdict(
        hour: 12, day: day(places: 0), lastNotifiedDate: null, now: noon);

    expect(notice.shows, isTrue);
    expect(notice.body, isNot(contains("чтений")));
  });
}
