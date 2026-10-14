import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/day_saints.dart';

// Святые дня из нашего каталога (`/api/v2/calendar/{date}/saints`).
// Покрытие связей ещё маленькое, поэтому пустой список — честный ответ,
// а `roundelUrl` у записи может отсутствовать вовсе.

void main() {
  DaySaints daySaints(String body) => DaySaints.fromJson(jsonDecode(body));

  test("ответ ручки разбирается: слуг, имя и кругляш", () {
    final parsed = daySaints(File("test/fixtures/day_saints.json").readAsStringSync());

    expect(parsed.date, "2026-01-16");
    expect(parsed.saints.length, 2);

    final withRoundel = parsed.saints.first;
    expect(withRoundel.slug, "ioann-predtecha");
    expect(withRoundel.name, "Иоа́нн Предте́ча");
    expect(withRoundel.roundelUrl, "https://cdn.dneslov.org/roundels/1/x.webp");
  });

  test("кругляш опционален: записи без него разбираются", () {
    final parsed = daySaints(File("test/fixtures/day_saints.json").readAsStringSync());

    expect(parsed.saints[1].slug, "savva-osvyashchennyi");
    expect(parsed.saints[1].roundelUrl, isNull);
  });

  test("пустой день — ответ, а не поломка", () {
    final parsed = daySaints('{"date": "2026-02-30", "saints": []}');

    expect(parsed.saints, isEmpty);
  });

  test("терпимость к недокачанному телу: список не пришёл — список пуст", () {
    final parsed = daySaints('{"date": "2026-01-16"}');

    expect(parsed.saints, isEmpty);
  });
}
