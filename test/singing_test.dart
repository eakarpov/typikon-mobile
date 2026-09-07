import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/api/singing.dart';
import 'package:typikon/dto/chant.dart';
import 'package:typikon/dto/incipit.dart';
import 'package:typikon/utils/incipit_route.dart';
import 'package:typikon/utils/singing_labels.dart';

// Певческий корпус. Два места, где ошибка молчит: подсветка фрагмента (сервер
// уже разметил его флагами, и потерять их — значит показать поиск без находки)
// и разделение соответствий на заявленные и предположенные.

// Настоящий ответ сервера, урезанный до одной строки.
const String chantJson = '''
{"items":[{
  "id": 31788,
  "snippet": [
    {"text": "Апостолом единонравныя: зри славник на Господи, ", "hit": false},
    {"text": "воззвах", "hit": true},
    {"text": ":", "hit": false}
  ],
  "unit": "stichera", "language": "cu_gr", "ode": null,
  "memoryId": "mineya-05-11-1", "memory": "Равноапостольных Кирилла и Мефодия",
  "book": "menaion", "month": 5, "day": 11, "service": "vespers",
  "position": "Стихиры на Господи воззвах", "tone": 6, "sign": null,
  "akathist": null, "stanza": null, "stanzaKind": null
}], "total": 213, "limit": 1, "offset": 0}
''';

Chant firstChant() =>
    Chant.fromJson(Map<String, dynamic>.from(jsonDecode(chantJson)["items"][0]));

void main() {
  group("песнопение", () {
    test("фрагмент приходит кусками, и найденное помечено", () {
      final chant = firstChant();

      expect(chant.snippet.length, 3);
      expect(chant.snippet.map((p) => p.hit), [false, true, false]);
      expect(chant.snippet[1].text, "воззвах");
    });

    test("склеенный фрагмент — весь текст, без потерь", () {
      // Куски не выбрасываются: подсветка их разметит, а не отберёт.
      expect(firstChant().plainText, contains("Апостолом"));
      expect(firstChant().plainText, endsWith(":"));
    });

    test("язык у строки есть", () {
      // Корпус четырёхъязычный: без языка славянскую стихиру не отличить от
      // румынской. Поле добавлено в v2 ради этого.
      expect(firstChant().language, "cu_gr");
    });

    test("адрес собирается от общего к частному", () {
      // Читатель спрашивает «где это поётся», и ответ на это праздник, а не книга.
      expect(chantAddress(firstChant()), [
        "Равноапостольных Кирилла и Мефодия",
        "вечерня",
        "Стихиры на Господи воззвах",
        "глас 6",
      ]);
    });

    test("без памяти в адрес идёт книга, а не пустота", () {
      final chant = Chant.fromJson({
        "id": 1,
        "snippet": [],
        "book": "octoechos",
        "service": "matins",
      });

      expect(chantAddress(chant), ["Октоих", "утреня"]);
    });

    test("у строфы акафиста адрес — имя произведения и номер строфы", () {
      final chant = Chant.fromJson({
        "id": 2,
        "snippet": [],
        "akathist": "Акафист Пресвятой Богородице",
        "stanza": 3,
      });

      expect(chantAddress(chant), ["Акафист Пресвятой Богородице", "строфа 3"]);
    });
  });

  group("подписи", () {
    test("известные коды переводятся", () {
      expect(languageLabel("cu_gr"), "ЦС");
      expect(serviceLabel("vespers"), "вечерня");
      expect(bookLabel("triod-postnaya"), "Триодь постная");
    });

    test("незнакомый код показывается как есть, а не прячется", () {
      // Списка допустимых значений API не отдаёт: их знает только корпус.
      // Заведут новый род — читатель увидит его непереведённым, но увидит.
      expect(serviceLabel("nokturn"), "nokturn");
      expect(bookLabel("psaltir-sledovannaya"), "psaltir-sledovannaya");
      expect(languageLabel(null), "");
    });
  });

  group("карточка зачина", () {
    final detail = IncipitDetail.fromJson(jsonDecode('''
      {"incipit": "воду прошед яко сушу и египетскаго", "language": "cu_gr",
       "uses": 134, "text": "Во́ду проше́д я́ко су́шу", "borrowed": true,
       "witnesses": [{"id": 8711, "unit": "irmos", "ode": 1, "tone": 6,
                      "service": "matins", "book": "menaion", "month": 1, "day": 2,
                      "memory": "Предпразднство Богоявления"}],
       "correspondences": {
         "declared": [{"language": "en", "text": "Having passed through the water",
                       "incipit": "having passed", "method": "edition",
                       "confidence": "certain", "evidence": "оба слоя одного издания"}],
         "supposed": [{"language": "grc", "text": "Βυθοῦ ἀνεκάλυψε",
                       "incipit": "βυθου", "method": "structure",
                       "confidence": "candidate", "evidence": "то же место службы"}]
       }}
    '''));

    test("заявленное и предположенное остаются раздельными", () {
      // Схлопнуть их в одно «перевод» значило бы выдать догадку за факт.
      expect(detail.declared.single.language, "en");
      expect(detail.supposed.single.language, "grc");
      expect(detail.declared.single.method, "edition");
      expect(detail.supposed.single.method, "structure");
    });

    test("основание связи приходит словами", () {
      // По нему читатель может нас проверить.
      expect(detail.supposed.single.evidence, "то же место службы");
      expect(correspondenceLabel(detail.supposed.single), "совпало место в службе");
      expect(correspondenceLabel(detail.declared.single), "так напечатано в издании");
    });

    test("заимствованный текст помечен", () {
      expect(detail.borrowed, isTrue);
    });

    test("адрес вхождения несёт песнь канона", () {
      // Ирмос первой песни и ирмос третьей — разные зачины.
      expect(witnessAddress(detail.witnesses.single), [
        "Предпразднство Богоявления",
        "утреня",
        "песнь 1",
        "глас 6",
      ]);
    });

    test("пустые соответствия не роняют разбор", () {
      final bare = IncipitDetail.fromJson(jsonDecode(
          '{"incipit": "а", "language": "cu_gr", "uses": 1, "text": "а"}'));

      expect(bare.hasCorrespondences, isFalse);
      expect(bare.witnesses, isEmpty);
      expect(bare.borrowed, isFalse);
    });
  });

  group("адрес карточки зачина", () {
    test("язык и ключ ходят туда и обратно", () {
      final argument = incipitRouteArgument("cu_gr", "воду прошед яко сушу и египетскаго");
      final target = parseIncipitArgument(argument);

      expect(target.language, "cu_gr");
      expect(target.incipit, "воду прошед яко сушу и египетскаго");
      expect(target.isValid, isTrue);
    });

    test("разделитель не встречается в самом ключе", () {
      // Ключ — строчные буквы, цифры и пробелы; перевода строки в нём быть не
      // может, а двоеточие или косая черта в чужом языке однажды встретятся.
      final argument = incipitRouteArgument("grc", "βυθου ανεκαλυψε πυθμενα");

      expect(argument.split("\n").length, 2);
      expect(parseIncipitArgument(argument).incipit, "βυθου ανεκαλυψε πυθμενα");
    });

    test("мусор вместо аргумента не открывает пустую карточку", () {
      expect(parseIncipitArgument("просто строка").isValid, isFalse);
    });
  });

  group("ключ кэша карточки", () {
    test("разные зачины не сталкиваются после чистки ключа", () {
      // _sanitizeKey сворачивает пробелы и знаки в подчёркивания, поэтому длина
      // входит в ключ: без неё «воду прошед» и «воду_прошед» легли бы в один файл.
      final a = _sanitized(incipitCacheKey("cu_gr", "воду прошед"));
      final b = _sanitized(incipitCacheKey("cu_gr", "воду  прошед"));

      expect(a, isNot(b));
    });

    test("язык различает одинаковые ключи", () {
      expect(incipitCacheKey("cu_gr", "воду"), isNot(incipitCacheKey("ro", "воду")));
    });
  });
}

String _sanitized(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
