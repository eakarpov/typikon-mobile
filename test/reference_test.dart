import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pericope.dart';
import 'package:typikon/dto/reference.dart';
import 'package:typikon/utils/lexeme_labels.dart';

// Справочные разделы. Общее у всех трёх — каждый отвечает не «вот текст», а
// «вот разбор», и у каждого есть чем разбор подпереть: признак догадки у имён,
// перечень непрочтённого у хронологии, пометка «выписано или порождено» у
// словаря. Потерять любую из подпорок — значит выдать вывод за факт.

void main() {
  group("зачало в указателе", () {
    final entry = PericopeEntry.fromJson(jsonDecode('''
      {"id": "6a82", "source": "gospel", "bookSlug": "marka", "number": 1,
       "variant": null, "label": "Мк. 1",
       "ranges": [{"chapterFrom": 1, "verseFrom": 1, "chapterTo": 1, "verseTo": 8}],
       "occasions": ["Неделя пред Богоявлением, 3-й час в навечерие Богоявления"]}
    '''));

    test("границы и адрес книги читаются", () {
      expect(entry.label, "Мк. 1");
      expect(entry.bookSlug, "marka");
      expect(entry.rangesLabel, "гл. 1, ст. 1–8");
    });

    test("когда читается — проза источника, а не перечисление", () {
      expect(entry.occasions.single, contains("Богоявлени"));
    });

    test("открывается в Библии, когда есть куда вести", () {
      expect(entry.opensInBible, isTrue);

      final noBook = PericopeEntry.fromJson(jsonDecode('{"id": "x", "label": "Мк. 1"}'));
      expect(noBook.opensInBible, isFalse);
    });

    test("откат на другой язык виден", () {
      // Чтение откатывается ЦЕЛИКОМ: сшитый из двух изданий отрывок выглядел бы
      // цельным, не будучи им.
      final same = PericopeReading.fromJson(jsonDecode(
          '{"id": "x", "label": "Мк. 1", "requestedLang": "cs", "resolvedLang": "cs"}'));
      final fell = PericopeReading.fromJson(jsonDecode(
          '{"id": "x", "label": "Мк. 1", "requestedLang": "ro", "resolvedLang": "cs"}'));

      expect(same.fellBack, isFalse);
      expect(fell.fellBack, isTrue);
    });
  });

  group("именины", () {
    final entry = NameEntry.fromJson(jsonDecode('''
      {"key": "анна", "name": "Анна", "year": 2026,
       "saints": [{"slug": "a", "name": "А́нна Матфа́новна", "confidence": "sure"}],
       "memories": [
         {"date": "2026-08-07", "movable": false,
          "saint": {"slug": "a", "name": "А́нна Матфа́новна", "confidence": "sure"}},
         {"date": "2026-04-08", "movable": true,
          "saint": {"slug": "g", "name": "Го́тфские", "confidence": "guess"}}
       ],
       "nameDay": {"date": "2026-04-08", "movable": true,
                   "saint": {"slug": "g", "name": "Го́тфские", "confidence": "guess"}},
       "caveat": "Правило народное, а не уставное."}
    '''));

    test("догадка остаётся догадкой", () {
      // Речь о том, когда человеку праздновать: догадка, выданная за факт,
      // стоит здесь дороже обычного.
      expect(entry.memories.firstWhere((m) => m.saint.slug == "g").saint.isGuess, isTrue);
      expect(entry.memories.firstWhere((m) => m.saint.slug == "a").saint.isGuess, isFalse);
    });

    test("переходящая память помечена", () {
      // В другой год она придётся на другое число, и дата без пометы соврала бы.
      expect(entry.memories.firstWhere((m) => m.movable).date, "2026-04-08");
    });

    test("оговорка приходит от сервера, а не сочиняется на месте", () {
      expect(entry.caveat, isNotEmpty);
    });

    test("именины без дня рождения не выдумываются", () {
      final bare = NameEntry.fromJson(jsonDecode(
          '{"key": "анна", "name": "Анна", "year": 2026, "caveat": ""}'));

      expect(bare.nameDay, isNull);
      expect(bare.memories, isEmpty);
    });
  });

  group("хронология", () {
    test("вердикт и уцелевшие читаются", () {
      final answer = ChronologyAnswer.fromJson(jsonDecode('''
        {"verdict": {"kind": "one", "text": "один год: мартовский и сентябрьский 6712"},
         "considered": 2, "applied": ["indikt"], "ignored": [],
         "survivors": [{"label": "мартовский и сентябрьский 6712", "leto": 6712,
                        "marks": {"indikt": 7, "krugSolntsu": 12, "krugLune": 3,
                                  "vrutseleto": 5, "vrutseletoLetter": "Д",
                                  "osnovanie": 11, "epakta": 19, "klyuchGranits": "З",
                                  "vysokosniy": false},
                        "day": {"julian": "1204-03-05", "civil": "1204-03-12",
                                "weekday": "пятница"}}],
         "fixes": []}
      '''));

      expect(answer.kind, "one");
      expect(answer.survivors.single.marks.indikt, 7);
      expect(answer.survivors.single.day?.weekday, "пятница");
    });

    test("непрочтённое условие доходит до экрана", () {
      // Без этого ответ выглядел бы подтверждённым тем, чего в переборе не было.
      final answer = ChronologyAnswer.fromJson(jsonDecode(
          '{"verdict": {"kind": "one", "text": "…"}, "ignored": ["weekday"], "applied": []}'));

      expect(answer.ignored, ["weekday"]);
    });

    test("поправка называет и прежнее чтение, и потребное", () {
      // «Читать не воскресенье, а пятницу» — довод, с которым идут к рукописи.
      final answer = ChronologyAnswer.fromJson(jsonDecode('''
        {"verdict": {"kind": "none", "text": "…"},
         "fixes": [{"field": "weekday", "label": "день недели",
                    "stated": "воскресенье", "needed": "пятница",
                    "candidate": {"label": "мартовский 6712", "marks": {}}}]}
      '''));

      final fix = answer.fixes.single;
      expect(fix.stated, "воскресенье");
      expect(fix.needed, "пятница");
      expect(fix.candidate.label, "мартовский 6712");
    });
  });

  group("словарь", () {
    final lexeme = Lexeme.fromJson(jsonDecode('''
      {"id": "1", "name": "земледѣ́ланіе", "scheme": "N2i", "pos": "noun",
       "properties": ["S", "n"], "known": true,
       "paradigms": [{"kind": "noun", "title": null, "base": null, "slots": [
         {"slot": "sgNom", "forms": [{"value": "земледѣ́ланіе", "stored": true}]},
         {"slot": "sgDat", "forms": [{"value": "земледѣ́ланію", "stored": false}]}
       ]}],
       "extra": []}
    '''));

    test("выписанное отличается от порождённого", () {
      // Факт и вывод — та же разница, что между заявленным и предположенным у
      // зачинов, и схлопывать её нельзя.
      final slots = lexeme.paradigms.single.slots;
      expect(slots.firstWhere((s) => s.slot == "sgNom").forms.single.stored, isTrue);
      expect(slots.firstWhere((s) => s.slot == "sgDat").forms.single.stored, isFalse);
    });

    test("грамматический адрес переводится в подпись", () {
      expect(slotLabel("sgNom"), "ед. им.");
      expect(slotLabel("duGenLoc"), "дв. род.-мест.");
      expect(slotLabel("aorPl3"), "аорист они");
    });

    test("пометы словаря переводятся, а не показываются кодом", () {
      // «S · n · inan» читателю не говорит ничего, а места под строкой ровно
      // столько же, сколько под словами. Найдено на устройстве: в коде это
      // выглядело безобидным «показываем как есть».
      expect(propertyLabel("inan"), "неодушевлённое");
      expect(propertyLabel("ipf"), "несовершенный вид");
      expect(propertyLabel("persn"), "личное имя");
    });

    test("часть речи не повторяется дважды", () {
      // Первой пометой обычно стоит она же: напечатанные подряд, они дали бы
      // «существительное · существительное · средний род».
      expect(propertyLabels("noun", ["S", "n", "inan"]),
          ["средний род", "неодушевлённое"]);
    });

    test("незнакомая помета показывается как есть", () {
      expect(propertyLabel("XYZ"), "XYZ");
      expect(propertyLabels("noun", ["S", "XYZ"]), ["XYZ"]);
    });

    test("незнакомая ячейка показывается как есть, а не прячется", () {
      // Заведут в словаре новую — читатель увидит её непереведённой, но увидит.
      expect(slotLabel("sgSuperEssive"), "sgSuperEssive");
    });

    test("парадигмы подписаны по своему роду", () {
      expect(paradigmTitle(lexeme.paradigms.single), "Склонение");
      expect(
        paradigmTitle(LexemeParadigm.fromJson(jsonDecode(
            '{"kind": "participle-plen", "title": "прич. прош. действ.", "slots": []}'))),
        "прич. прош. действ. — полная форма",
      );
    });

    test("отсутствие таблицы склонения не выдаётся за отсутствие форм", () {
      final unknown = Lexeme.fromJson(jsonDecode(
          '{"id": "2", "name": "а́ще", "known": false, "paradigms": [], '
          '"extra": [{"value": "а́ще", "stored": true}]}'));

      expect(unknown.known, isFalse);
      expect(unknown.extra.single.value, "а́ще");
    });
  });
}
