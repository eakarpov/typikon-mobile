import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/saint.dart';
import 'package:typikon/utils/singing_labels.dart';

// Досье святого. Половина связей в каталоге не выверена, и почти всё здесь —
// про то, чтобы не выдать нашу неполноту за отсутствие: пустой раздел, не
// сказавший, что он пустой по нашей вине, врёт о святом.

SaintDossier dossier(String body) => SaintDossier.fromJson(jsonDecode(body));

void main() {
  group("разбор досье", () {
    final saint = dossier('''
      {"slug": "aleksandr-svirskii", "name": "Алекса́ндр Сви́рский",
       "altNames": ["Амо́съ"], "kind": "Identity", "kindLabel": null,
       "orders": [{"code": "прп", "label": "преподобный"}],
       "baseYear": 1533, "baseYearLabel": "1533",
       "memoryDates": [{"raw": "30.08", "julian": "30 августа",
                        "civil": "12 сентября 2026", "iso": "2026-09-12", "note": null}],
       "roundelUrl": "https://cdn.dneslov.org/roundels/57/x.webp", "images": [],
       "externals": [{"source": "dneslov", "id": "2757"}],
       "memories": [{"memoryId": "mineya-08-30-4", "label": "Преподо́бнаго Алекса́ндра",
                     "address": "Минея, 30 августа", "sign": "slavoslovie"}],
       "texts": [{"id": "a1", "name": "Служба", "description": null, "author": null}],
       "mentions": [],
       "akathists": [], "dedications": [{"slug": "aleksandr-svirsky", "short": "Александр Свирский",
                                         "label": "Преподо́бнаго отца́", "count": 21}],
       "noble": null, "caveat": "Пустой раздел чаще значит, что связь ещё не проставлена."}
    ''');

    test("имя, чин и опорный год читаются", () {
      expect(saint.name, "Алекса́ндр Сви́рский");
      expect(saint.orders.single.label, "преподобный");
      expect(saint.baseYearLabel, "1533");
    });

    test("вид записи без подписи не подменяется кодом", () {
      // `Identity` — наше служебное слово, и показывать его читателю нельзя;
      // сервер это знает и подписи не даёт.
      expect(saint.kindLabel, isNull);
    });

    test("оговорка приходит от сервера, а не сочиняется на месте", () {
      expect(saint.caveat, isNotEmpty);
    });
  });

  group("чего мы не знаем", () {
    test("невыложенный корпус акафистов отличается от их отсутствия", () {
      // `null` — не смотрели вовсе, `[]` — смотрели и не нашли. Схлопнув, мы
      // сказали бы «акафистов нет» там, где не открывали книгу.
      final unknown = dossier('{"name": "А", "akathists": null}');
      final looked = dossier('{"name": "А", "akathists": []}');

      expect(unknown.akathistsUnknown, isTrue);
      expect(looked.akathistsUnknown, isFalse);
      expect(looked.akathists, isEmpty);
    });

    test("отсутствие поля акафистов тоже читается как «не смотрели»", () {
      expect(dossier('{"name": "А"}').akathistsUnknown, isTrue);
    });
  });

  group("житие", () {
    test("контракт прокси разбирается: слуг, источник, памяти и ссылки", () {
      final life = SaintLife.fromJson(jsonDecode(
          File("test/fixtures/saint_life.json").readAsStringSync()));

      expect(life.slug, "zaharia");
      expect(life.source, "dneslov");
      expect(life.memoes.length, 2);
      expect(life.memo!.title, "Заха́рия");
      expect(life.memo!.happenedAt, isNull);
      expect(life.hasText, isTrue);
      expect(life.links.single.url, "https://dneslov.org/zaharia");
    });

    test("слуг стороннего каталога держится отдельно от нашего", () {
      // Наш слуг и слуг каталога памятей расходятся, а ссылка «открыть
      // источник» строится по их слугу — подставив наш, мы увели бы в никуда.
      final life = SaintLife.fromJson(jsonDecode(
          '{"slug": "zaharia", "memoes": [{"title": "Заха́рия", "description": "Житие."}]}'));

      expect(life.slug, "zaharia");
      expect(life.memo!.title, "Заха́рия");
      expect(life.hasText, isTrue);
    });

    test("память без описания — не житие, а не незагрузившийся текст", () {
      // Сервер такие памяти опускает; если всё же пришли без описания,
      // показывать их как текст нечего.
      final empty = SaintLife.fromJson(jsonDecode(
          '{"slug": "x", "source": "dneslov", "memoes": [], "links": []}'));
      final blank = SaintLife.fromJson(jsonDecode(
          '{"slug": "x", "memoes": [{"title": "Т"}, {"title": "Т", "description": "   "}]}'));

      expect(empty.hasText, isFalse);
      expect(blank.hasText, isFalse);
    });
  });

  group("знак службы", () {
    test("подписывается словарём корпуса, а не месяцеслова", () {
      // Знаки месяцеслова записаны заглавными (`DOXOLOGIC`), знаки корпуса —
      // слугами. Взяв не тот словарь, знак получишь пустым, и никто не заметит.
      expect(serviceSignLabel("slavoslovie"), "славословие");
      expect(serviceSignLabel("bdenie"), "бдение");
    });

    test("незнакомый знак показывается как есть, а не прячется", () {
      expect(serviceSignLabel("neznakomy"), "neznakomy");
    });

    test("отсутствие знака — пустая подпись, а не слово", () {
      expect(serviceSignLabel(null), "");
      expect(serviceSignLabel(""), "");
    });
  });
}
