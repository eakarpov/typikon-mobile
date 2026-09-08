import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pomyannik.dart';
import 'package:typikon/utils/pomyannik_labels.dart';

// Помянник. Всё здесь либо о том, чего мы не знаем и не должны выдумывать
// (церковнославянское начертание пометы, склонение имени), либо о датах, где
// ошибка на день пропускает день поминовения.

Person person(String body) => Person.fromJson(jsonDecode(body));

void main() {
  group("лицо", () {
    final anna = person('''
      {"id": "1", "name": "Юрий", "churchName": "Георгий", "kind": "living",
       "sex": "m", "rank": "bolyashchiy", "relation": "крёстный",
       "born": "1975-03-12", "baptized": null, "died": null,
       "nameDay": {"source": "auto", "style": "old", "month": 4, "day": 23,
                   "offset": null, "saint": "georgiy-pobedonosec"},
       "sorokoust": null, "groups": [], "order": 3}
    ''');

    test("имя наречения и привычное показываются оба", () {
      // Молча подменить одно другим значило бы решить за человека, кем его
      // крестили.
      expect(anna.display, "Георгий (Юрий)");
      expect(anna.commemorated, "Георгий", reason: "в записке поминают по имени наречения");
    });

    test("родство остаётся у хозяина", () {
      // «Крёстный» помогает не спутать двух Николаев, но в записку не идёт: там
      // поминают по имени, а не по родству.
      expect(anna.relation, "крёстный");
    });

    test("неподвижная память и подвижная различаются", () {
      // Подвижная в другой год придётся на другое число, и хранить её числом
      // нельзя вовсе.
      expect(anna.nameDay!.movable, isFalse);

      final movable = person('{"id":"2","name":"А","nameDay":{"source":"manual","offset":9}}');
      expect(movable.nameDay!.movable, isTrue);
      expect(movable.nameDay!.day, isNull, reason: "числа у подвижной памяти нет вовсе");
    });

    test("без церковного имени скобок не появляется", () {
      expect(person('{"id":"3","name":"Анна"}').display, "Анна");
      expect(person('{"id":"3","name":"Анна","churchName":"Анна"}').display, "Анна");
    });
  });

  group("правка уходит лицом целиком", () {
    test("стёртое поле уезжает как null, а не пропадает", () {
      // Сервер иначе не отличит «не трогай» от «сотри», и на этом вопросе рано
      // или поздно теряется дата преставления.
      final cleared = person('{"id":"1","name":"Анна","died":"2019-03-12"}')
          .copyWith(died: null);

      final input = cleared.toInput();
      expect(input.containsKey("died"), isTrue);
      expect(input["died"], isNull);
    });

    test("непереданное поле остаётся прежним", () {
      final same = person('{"id":"1","name":"Анна","died":"2019-03-12","rank":"monah"}')
          .copyWith(name: "Анна Ивановна");

      expect(same.died, "2019-03-12");
      expect(same.rank, "monah");
    });
  });

  group("счёт дней приходит с сервера", () {
    final card = PersonCard.fromJson(jsonDecode('''
      {"on": "2026-09-08",
       "person": {"id": "1", "name": "Николай", "kind": "departed", "died": "2026-08-01"},
       "memorial": {"third": "2026-08-03", "ninth": "2026-08-09",
                    "fortieth": "2026-09-09", "newlyDeparted": true, "years": 0},
       "sorokoust": {"from": "2026-08-09", "to": "2026-09-17",
                     "passed": 31, "left": 9, "done": false}}
    '''));

    test("третий, девятый и сороковой день разбираются как есть", () {
      // Считаются они от дня преставления, который сам считается первым: третий
      // — через двое суток, девятый — через восемь, сороковой — через тридцать
      // девять. Повторять это на своей стороне мы не станем.
      expect(card.memorial!.third, "2026-08-03");
      expect(card.memorial!.ninth, "2026-08-09");
      expect(card.memorial!.fortieth, "2026-09-09");
    });

    test("сорокоуст — не сороковой день", () {
      // Заказанный на девятый день, он кончится на сорок восьмой, и сходиться с
      // сороковым днём ему незачем.
      expect(card.sorokoust!.to, isNot(card.memorial!.fortieth));
      expect(card.sorokoust!.done, isFalse);
    });

    test("карточка знает, на какое число посчитана", () {
      // «Новопреставленный» живёт сорок дней и протухает в полночь; карточка,
      // пролежавшая открытой через полночь, обязана перезапроситься.
      expect(card.staleOn("2026-09-08"), isFalse);
      expect(card.staleOn("2026-09-09"), isTrue);
    });

    test("у живого счёта нет, и это не пустой счёт", () {
      final living = PersonCard.fromJson(jsonDecode(
          '{"on":"2026-09-08","person":{"id":"2","name":"Анна"},"memorial":null,"sorokoust":null}'));

      expect(living.memorial, isNull);
      expect(living.sorokoust, isNull);
    });
  });

  group("ближайшее", () {
    final upcoming = Upcoming.fromJson(jsonDecode('''
      {"from": "2026-09-08", "days": 60, "events": [
        {"date": "2026-09-12", "kind": "nameday", "personId": "1", "name": "Александр",
         "years": null, "title": "Именины: Александр", "custom": false, "note": null},
        {"date": "2026-11-07", "kind": "memorial-day", "personId": null, "name": null,
         "title": "Суббота Димитриевская", "custom": true,
         "note": "в разных митрополиях считается неодинаково"}
      ]}
    '''));

    test("окно помнит, с какого дня посчитано", () {
      // Подвижные памяти и годовщины считаются от него: окно, посчитанное
      // вчера, начинается вчера.
      expect(upcoming.from, "2026-09-08");
    });

    test("неуставный день помечен, и помета доходит до экрана", () {
      // Без неё список выглядит уставным целиком.
      final dmitry = upcoming.events.firstWhere((e) => e.kind == "memorial-day");
      expect(dmitry.custom, isTrue);
      expect(dmitry.note, isNotEmpty);
    });

    test("общий день ни к кому не привязан", () {
      expect(upcoming.events.last.personId, isNull);
    });
  });

  group("словарь чинов", () {
    final vocabulary = Vocabulary.fromJson(jsonDecode('''
      {"ranks": [
        {"key": "ierey", "label": "иерей", "genitive": "иерея", "cs": "їере́а",
         "feminine": null, "only": null},
        {"key": "bolyashchiy", "label": "болящий", "genitive": "болящего", "cs": null,
         "feminine": {"label": "болящая", "genitive": "болящую", "cs": null},
         "only": "living"},
        {"key": "ubiennyy", "label": "убиенный", "genitive": "убиенного", "cs": null,
         "feminine": null, "only": "departed"}
      ],
       "noteKinds": [
        {"key": "panihida", "label": "Панихида", "about": "departed", "days": 0, "note": ""},
        {"key": "proskomidia", "label": "Обедня", "about": "both", "days": 0, "note": ""}
       ],
       "limits": {"maxPersons": 500, "maxBatch": 200, "maxNamesInNote": 20}}
    '''));

    test("«не знаем» доживает до экрана как null", () {
      // У пяти помет церковнославянского начертания в наших книгах нет, и `null`
      // здесь значит «книгой не подтверждено». Схлопнув его в пустую строку, мы
      // однажды напечатали бы в записке выдуманное за книгу.
      expect(vocabulary.rank("ierey")!.masculine.cs, "їере́а");
      expect(vocabulary.rank("bolyashchiy")!.masculine.cs, isNull);
    });

    test("женская форма берётся по полу, а есть она не у всякого чина", () {
      expect(vocabulary.rank("bolyashchiy")!.formFor("f").label, "болящая");
      expect(vocabulary.rank("ierey")!.formFor("f").label, "иерей");
    });

    test("помета живым не предлагается усопшему", () {
      expect(vocabulary.rank("bolyashchiy")!.suits("living"), isTrue);
      expect(vocabulary.rank("bolyashchiy")!.suits("departed"), isFalse);
      expect(vocabulary.rank("ierey")!.suits("departed"), isTrue);
    });

    test("незнакомый чин не подписывается вовсе", () {
      // Пока словарь не пришёл или чин в нём новый — лучше без чина, чем с чужим.
      expect(vocabulary.rank("nesuschestvuyuschiy"), isNull);
      expect(rankLabel(vocabulary, person('{"id":"1","name":"А","rank":"nesuschestvuyuschiy"}')), "");
      expect(rankLabel(const Vocabulary(), person('{"id":"1","name":"А","rank":"ierey"}')), "");
    });

    test("панихида о живых не служится, обедня — о всех", () {
      final panihida = vocabulary.noteKinds.firstWhere((k) => k.key == "panihida");
      expect(panihida.accepts("living"), isFalse);
      expect(panihida.accepts("departed"), isTrue);
      expect(vocabulary.noteKinds.last.accepts("living"), isTrue);
    });
  });

  group("записка", () {
    final sheet = NoteSheet.fromJson(jsonDecode('''
      {"kind": {"key": "proskomidia", "label": "Обедня", "about": "both", "days": 0, "note": ""},
       "span": null,
       "names": [
         {"name": "Николай", "churchName": null, "slavonic": "нїкола́а",
          "slavonicSource": "lexicon", "kind": "departed", "rank": null, "sex": "m"},
         {"name": "Свiтлана", "churchName": null, "slavonic": "свiтлана",
          "slavonicSource": "accents", "kind": "living", "rank": null, "sex": "f"}
       ]}
    '''));

    test("склонённое отличается от несклонённого", () {
      // Приняв наш именительный за проверенный родительный, человек отдаст
      // записку с ошибкой, которой сам бы не сделал.
      expect(sheet.names.first.declined, isTrue);
      expect(sheet.names.last.declined, isFalse);
      expect(sheet.undeclined.single.name, "Свiтлана");
    });

    test("имена разложены по разделам записки", () {
      expect(sheet.departedNames.single.name, "Николай");
      expect(sheet.livingNames.single.name, "Свiтлана");
    });

    test("без церковнославянского печатается то, что вписали", () {
      final plain = NoteName.fromJson(jsonDecode(
          '{"name":"Świętosław","churchName":null,"slavonic":null,'
          '"slavonicSource":null,"kind":"living"}'));

      expect(plain.text, "Świętosław");
      expect(plain.declined, isFalse);
    });
  });

  group("поданная записка", () {
    test("стёртая по сроку помнит, сколько имён было", () {
      // Стираются ИМЕНА, а не запись: они принадлежат третьим лицам, а история
      // «что и когда подавали» остаётся счётом.
      final swept = Zapiska.fromJson(jsonDecode('''
        {"id": "1", "kind": "sorokoust", "names": [], "namesCount": 7,
         "span": {"from": "2026-08-01", "to": "2026-09-09"},
         "createdAt": "2026-08-01T09:00:00.000Z", "readAt": "2026-08-01T10:00:00.000Z",
         "finishedAt": null, "sweptAt": "2026-10-09T00:00:00.000Z"}
      '''));

      expect(swept.names, isEmpty);
      expect(swept.namesCount, 7);
      expect(swept.swept, isTrue);
    });

    test("окончить можно только прочитанное и длящееся", () {
      final unread = Zapiska.fromJson(jsonDecode(
          '{"id":"1","kind":"sorokoust","span":{"from":"a","to":"b"},"readAt":null}'));
      final once = Zapiska.fromJson(jsonDecode(
          '{"id":"2","kind":"panihida","span":null,"readAt":"2026-08-01T10:00:00.000Z"}'));
      final running = Zapiska.fromJson(jsonDecode(
          '{"id":"3","kind":"sorokoust","span":{"from":"a","to":"b"},'
          '"readAt":"2026-08-01T10:00:00.000Z"}'));

      expect(unread.finishable, isFalse);
      expect(once.finishable, isFalse, reason: "разовое поминовение не оканчивают");
      expect(running.finishable, isTrue);
    });
  });

  group("подписи", () {
    test("день до события называется словом, а не числом", () {
      expect(inDays(0), "сегодня");
      expect(inDays(1), "завтра");
      expect(inDays(2), "послезавтра");
      expect(inDays(3), "через 3 дня");
      expect(inDays(5), "через 5 дней");
      expect(inDays(11), "через 11 дней");
      expect(inDays(21), "через 21 день");
      expect(inDays(22), "через 22 дня");
    });

    test("годы согласуются с числом", () {
      expect(years(1), "1 год");
      expect(years(2), "2 года");
      expect(years(5), "5 лет");
      expect(years(11), "11 лет");
      expect(years(12), "12 лет");
      expect(years(21), "21 год");
    });

    test("дата пишется по-русски, и год опускается по требованию", () {
      expect(humanDate("2019-03-12"), "12 марта 2019");
      expect(humanDate("2019-03-12", withYear: false), "12 марта");
      expect(humanDate("не дата"), "");
      expect(humanDate(null), "");
    });

    test("день недели в именительном падеже", () {
      // Он стоит в перечне сам по себе — «11 сентября, пятница», — а не после
      // предлога.
      expect(weekdayOf("2026-09-11"), "пятница");
      expect(weekdayOf("2026-09-13"), "воскресенье");
    });

    test("сегодняшнее число берётся местное, а не серверное", () {
      // В час пополуночи по местному времени серверное «сегодня» бывает
      // вчерашним, и окно ближайших дней начиналось бы не с того дня.
      expect(today(DateTime(2026, 9, 8, 0, 30)), "2026-09-08");
      expect(today(DateTime(2026, 1, 2)), "2026-01-02");
    });

    test("прописная поднимает букву, а не знак над нею", () {
      // Словарь хранит леммы строчными, и склонение выдаёт их такими же; слово
      // может начинаться со звательца или придыхания.
      expect(capitalize("нїкола́а"), "Нїкола́а");
      expect(capitalize("҃і҆ѡа́нна"), "҃І҆ѡа́нна");
      expect(capitalize(""), "");
    });

    test("незнакомый род события показывается как есть", () {
      expect(eventLabel("fortieth"), "сороковой день");
      expect(eventLabel("sorokoust-end"), "оканчивается сорокоуст");
      expect(eventLabel("nechto-novoe"), "nechto-novoe");
    });
  });
}
