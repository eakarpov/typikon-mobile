import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/corpus.dart';
import 'package:typikon/utils/chant_style.dart';
import 'package:typikon/utils/singing_labels.dart';

// Каноны, акафисты, молитвы. Три места, где ошибка молчит и правдоподобна.
//
// Номер песни — не порядковый: второй песни нет ни у кого, кроме Великого
// канона. Перенумеровав их подряд, мы «починим» пропуск, которого нет.
//
// Проимий акафиста по форме кондак, и по паре «род и номер» он сталкивается с
// первым кондаком акростиха. Различает только `kind`.
//
// Достоинство акафиста: уставом положен ровно один из 1102, и перечень без этой
// пометы обещает читателю обратное.

void main() {
  group("канон", () {
    // Настоящий ответ сервера, урезанный: у этого канона нет второй песни.
    final canon = CanonDetail.fromJson(jsonDecode('''
      {"id": "en-en-acook-me.m02.d27-matins-canon1",
       "memory": "Преподо́бнаго отца́ на́шего Проко́пия",
       "book": "menaion", "month": 2, "day": 27, "paschaOffset": null,
       "weekday": null, "memoryTone": null, "tone": 2,
       "creator": "Творе́ние Ио́сифово. Гла́с 2.", "author": "Иосиф Песнописец",
       "authorCentury": "IX", "acrostic": null, "service": "matins",
       "role": null, "odes": 8, "items": 30,
       "odesList": [
         {"ode": 1, "irmos": [], "troparia": [
            {"unit": "troparion", "text": "Пе́рвое сло́во", "borrowed": false,
             "marker": null, "repeat": 1}]},
         {"ode": 3, "irmos": [
            {"unit": "irmos", "text": "Ирмо́с из Ирмология", "borrowed": true,
             "marker": null, "repeat": 2}], "troparia": []}
       ]}
    '''));

    test("номер песни берётся из книги, а не из порядка", () {
      expect(canon.odes.map((o) => o.ode).toList(), [1, 3]);
    });

    test("неразрешённая ссылка — не текст песнопения", () {
      // Греческий слой ссылается на Ирмологий, которого в корпусе нет: 2697
      // строк из 2718 неразрешённых оттуда. Напечатанный уставным кеглем,
      // опознаватель прочтётся читателем как ирмос.
      final line = CanonLine.fromJson(jsonDecode(
          '{"unit": "irmos", "text": "", "borrowed": false, '
          '"reference": "he.h.m2.heHE.DefteLaoi", "repeat": 1}'));

      expect(line.isUnresolved, isTrue);
      expect(line.text, isEmpty);
      expect(line.reference, "he.h.m2.heHE.DefteLaoi");
    });

    test("разрешённая ссылка неразрешённой не считается", () {
      final line = CanonLine.fromJson(jsonDecode(
          '{"unit": "irmos", "text": "Гряди́те, лю́дие", "borrowed": true, '
          '"reference": null, "repeat": 1}'));

      expect(line.isUnresolved, isFalse);
      expect(line.borrowed, isTrue);
    });

    test("подставленный текст назван подставленным", () {
      // Книга печатает ирмос зачином, полный лежит в Ирмологии. Неподписанный,
      // он выдавался бы за напечатанный здесь.
      final irmos = canon.odes.last.irmos.single;
      expect(irmos.borrowed, isTrue);
      expect(canon.odes.first.troparia.single.borrowed, isFalse);
    });

    test("повтор — указание книги, и оно доходит", () {
      expect(canon.odes.last.irmos.single.repeat, 2);
      expect(canon.odes.first.troparia.single.repeat, 1);
    });

    test("надписание и лицо стоят порознь", () {
      // Напечатанное есть свидетельство, отождествление — вывод из него, и
      // вывод бывает неверен.
      expect(canon.canon.creator, "Творе́ние Ио́сифово. Гла́с 2.");
      expect(canon.canon.authorLabel, "Иосиф Песнописец, IX в.");
    });

    test("без отождествления остаётся одно надписание", () {
      final bare = Canon.fromJson(jsonDecode(
          '{"id":"x","memory":"М","creator":"Творе́ние Ко́смы.","author":null}'));

      expect(bare.authorLabel, isEmpty);
      expect(bare.creator, isNotEmpty);
    });
  });

  group("акафист", () {
    final akathist = AkathistDetail.fromJson(jsonDecode('''
      {"id": "velikiy-akafist", "title": "Великий акафист", "subjectKind": "bogorodica",
       "status": "ustavny", "dneslovId": null, "memoryId": "m", "memory": "Суббота 5-й седмицы",
       "stanzas": 25, "prooimia": 1,
       "refrainIkos": "Ра́дуйся, Неве́сто Неневе́стная.", "refrainKontakion": "Аллилу́иа.",
       "sourceBook": "triod-postnaya", "sourceUrl": null,
       "stanzasList": [
         {"index": 1, "kind": "prooimion", "unit": "kontakion", "stanza": 1,
          "letter": null, "text": "Взбра́нной Воево́де"},
         {"index": 2, "kind": "stanza", "unit": "ikos", "stanza": 1,
          "letter": "Α", "text": "А́нгел предста́тель"},
         {"index": 3, "kind": "stanza", "unit": "kontakion", "stanza": 2,
          "letter": "Β", "text": "Ви́дящи Свята́я"}
       ],
       "prayers": []}
    '''));

    test("проимий отличается от кондака не номером, а родом", () {
      // По паре «кондак + номер» проимий и первый кондак акростиха разошлись бы
      // по разным концам, а стоят они рядом.
      final first = akathist.stanzas.first;
      expect(first.isProoimion, isTrue);
      expect(stanzaLabel(first.unit, first.stanza, first.kind), "проимий 1");
      expect(stanzaLabel("kontakion", 2, "stanza"), "кондак 2");
      expect(stanzaLabel("ikos", 1, "stanza"), "икос 1");
    });

    test("порядок показа — порядок чтения", () {
      expect(akathist.stanzas.map((s) => s.index).toList(), [1, 2, 3]);
    });

    test("буква краегранесия доходит до экрана", () {
      // Недостающая буква значит потерянную строфу — по ней и проверяется
      // полнота разбора.
      expect(akathist.stanzas[1].letter, "Α");
      expect(akathist.stanzas.first.letter, isNull);
    });

    test("уставный отличается от частного, и оба подписаны", () {
      expect(akathist.akathist.isUstavny, isTrue);
      expect(akathistStatusLabel("ustavny"), "положен уставом");
      expect(akathistStatusLabel("chastny"), "частное сочинение");
    });

    test("«иное» подписано, хотя на сайте выпадает латиницей", () {
      // Шестнадцать акафистов Кресту, Ангелам, ко Причащению.
      expect(subjectKindLabel("inoe"), "иное");
      expect(subjectKindLabel("ikona"), "пред иконой");
    });
  });

  group("молитва", () {
    test("безымянную называет тот, при ком она стоит", () {
      // Двести тридцать пять из тысячи подписаны просто «Молитва».
      final bare = Prayer.fromJson(jsonDecode(
          '{"id":"p","title":null,"kind":"akathist","owner":"Акафист Благовещению"}'));

      expect(bare.display, "Молитва");
      expect(prayerKindLabel("akathist"), "при акафисте");
    });

    test("соседи приходят подписью и порядком", () {
      final detail = PrayerDetail.fromJson(jsonDecode(
          '{"id":"p","title":"Моли́тва 1-я","kind":"akathist","owner":"А","ownerId":"a",'
          '"seq":1,"text":"Приими́","siblings":[{"id":"q","title":"Моли́тва 2-я","seq":2}]}'));

      expect(detail.siblings.single.display, "Моли́тва 2-я");
      expect(detail.prayer.ownerId, "a");
    });
  });

  group("страница с отборами", () {
    final page = FacetedPage.fromJson<Canon, CanonFacets>(
      jsonDecode('{"items":[{"id":"c","memory":"М"}],"total":3411,"limit":25,"offset":0,'
          '"facets":{"books":["menaion"],"tones":[1,2],"services":["matins"],"roles":["voskresny"]}}'),
      Canon.fromJson,
      CanonFacets.fromJson,
    );

    test("отборы приезжают вместе с выдачей", () {
      // Зашитый у нас список разошёлся бы с корпусом молча — как только там
      // заведут новую роль.
      expect(page.facets.books, ["menaion"]);
      expect(page.facets.tones, [1, 2]);
    });

    test("есть ли ещё — по числу полученного, а не по limit", () {
      expect(page.hasMore, isTrue);

      final last = FacetedPage.fromJson<Canon, CanonFacets>(
        jsonDecode('{"items":[],"total":3411,"limit":25,"offset":3400,"facets":{}}'),
        Canon.fromJson,
        CanonFacets.fromJson,
      );
      expect(last.hasMore, isFalse, reason: "пустая страница — конец, что бы ни говорил total");
    });
  });

  group("строки песнопения", () {
    test("косая черта — перевод строки, а не знак препинания", () {
      expect(
        chantLines("Взбра́нной Воево́де победи́тельная, / я́ко изба́вльшеся"),
        ["Взбра́нной Воево́де победи́тельная,", "я́ко изба́вльшеся"],
      );
    });

    test("пустых строк посреди текста не появляется", () {
      expect(chantLines("сло́во, / / и҆ сло́во").length, 2);
      expect(chantLines("одна строка"), ["одна строка"]);
      expect(chantLines(""), isEmpty);
    });
  });
}
