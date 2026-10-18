import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/posledovanie.dart';

// Разбор последования молитвослова. Рука молодая и в открытой зоне — сервер
// правит её чаще, чем приложение, поэтому разбор обязан быть tolerant:
// незнакомое поле — пропустить, мусорный ряд — перешагнуть.

void main() {
  test("полный ряд разбирается целиком", () {
    final posledovanie = Posledovanie.fromJson(<String, dynamic>{
      "key": "na-son",
      "lang": "cu",
      "rows": <Map<String, dynamic>>[
        <String, dynamic>{
          "label": "Моли́тва 1-я",
          "lead": "Иере́й",
          "repeatCount": 3,
          "poklon": true,
          "note": "И поклоня́ются до земли́.",
          "text": "Господу пое́мъ",
        },
      ],
    });

    expect(posledovanie.key, "na-son");
    expect(posledovanie.lang, "cu");
    expect(posledovanie.rows, hasLength(1));

    final row = posledovanie.rows.single;
    expect(row.label, "Моли́тва 1-я");
    expect(row.lead, "Иере́й");
    expect(row.repeatCount, 3);
    expect(row.poklon, isTrue);
    expect(row.note, "И поклоня́ются до земли́.");
    expect(row.text, "Господу пое́мъ");
  });

  test("ряд без всего: текст пустой, флаги ложные", () {
    final row = PosledovanieRow.fromJson(const <String, dynamic>{});

    expect(row.label, isNull);
    expect(row.lead, isNull);
    expect(row.repeatCount, isNull);
    expect(row.poklon, isFalse);
    expect(row.note, isNull);
    expect(row.text, "");
  });

  test("поклон строкой считается поклоном", () {
    // Сервер вправе прислать указание о поклоне строкой, а не булевым.
    expect(
      PosledovanieRow.fromJson(const <String, dynamic>{"poklon": "земной"}).poklon,
      isTrue,
    );
    expect(
      PosledovanieRow.fromJson(const <String, dynamic>{"poklon": ""}).poklon,
      isFalse,
    );
    expect(
      PosledovanieRow.fromJson(const <String, dynamic>{"poklon": false}).poklon,
      isFalse,
    );
  });

  test("repeatCount терпит строку и мусор", () {
    expect(
      PosledovanieRow.fromJson(const <String, dynamic>{"repeatCount": "3"})
          .repeatCount,
      3,
    );
    expect(
      PosledovanieRow.fromJson(const <String, dynamic>{"repeatCount": "много"})
          .repeatCount,
      isNull,
    );
  });

  test("мусорные ряды перешагиваются, rows мимо списка пуст", () {
    final posledovanie = Posledovanie.fromJson(<String, dynamic>{
      "key": "na-son",
      "lang": "cu",
      "rows": <dynamic>[
        null,
        "не ряд",
        42,
        <String, dynamic>{"text": "Ами́нь."},
      ],
    });

    expect(posledovanie.rows, hasLength(1));
    expect(posledovanie.rows.single.text, "Ами́нь.");

    final noRows = Posledovanie.fromJson(const <String, dynamic>{
      "key": "na-son",
      "lang": "cu",
    });
    expect(noRows.rows, isEmpty);

    final rowsNotList =
        Posledovanie.fromJson(const <String, dynamic>{"rows": "нет"});
    expect(rowsNotList.rows, isEmpty);
  });

  test("незнакомые поля не мешают", () {
    final posledovanie = Posledovanie.fromJson(<String, dynamic>{
      "key": "na-son",
      "lang": "cu",
      "futureField": <String, dynamic>{"anything": true},
      "rows": <Map<String, dynamic>>[
        <String, dynamic>{
          "text": "Бу́ди и́мя Госпо́дне",
          "anotherFuture": 1,
        },
      ],
    });

    expect(posledovanie.rows.single.text, "Бу́ди и́мя Госпо́дне");
  });
}
