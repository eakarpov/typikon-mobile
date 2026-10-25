import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/utils/bible_editions.dart';
import 'package:typikon/utils/bible_sections.dart';
import 'package:typikon/utils/bible_style.dart';

// Оглавление и выбор издания. Две вещи, которые ломаются тихо: порядок разделов
// (Иона окажется не там, где его ищут) и шрифт (текст осыплется квадратами, и
// читатель решит, что сломалось приложение).

BibleBook book(String id, String section, {bool inCanon = true}) => BibleBook(
  id: id,
  name: id,
  abbr: id,
  section: section,
  inCanon: inCanon,
  chapters: inCanon ? 1 : null,
);

BibleEdition edition(
  String code,
  String language, {
  String versification = "other",
}) => BibleEdition(
  code: code,
  title: code,
  shortTitle: code,
  language: language,
  languageCode: code,
  versification: versification,
);

void main() {
  group("разбивка на разделы", () {
    test("порядок разделов и книг берётся из ответа, а не задаётся у нас", () {
      // Канон приходит в порядке Елизаветинской Библии, а разделы в нём —
      // сплошные отрезки. Свой порядок был бы второй копией того же знания.
      final groups = groupBySection([
        book("bytie", "pentateuch"),
        book("iskhod", "pentateuch"),
        book("iisus-navin", "historical"),
        book("matfeya", "gospel"),
      ]);

      expect(groups.map((g) => g.id), ["pentateuch", "historical", "gospel"]);
      expect(groups.first.books.map((b) => b.id), ["bytie", "iskhod"]);
    });

    test("разделы получают русские имена", () {
      final groups = groupBySection([book("bytie", "pentateuch")]);

      expect(groups.single.label, "Пятикнижие");
    });

    test("незнакомый раздел показывается как есть, а не прячется", () {
      // Заведёт веб новый раздел — книги останутся видны, просто под
      // непереведённым именем.
      final groups = groupBySection([book("nechto", "novyy-razdel")]);

      expect(groups.single.label, "novyy-razdel");
      expect(groups.single.books, hasLength(1));
    });

    test("пустой список не роняет разбивку", () {
      expect(groupBySection(const []), isEmpty);
    });
  });

  group("какое издание просить", () {
    final available = BibleEditionList([
      edition("grc-lxx-pat", "grc"),
      edition("cs-eliz", "cu", versification: "sla-lxx"),
      edition("zh-1910", "zh"),
    ]);

    test("по умолчанию берётся эталон, а не первый попавшийся", () {
      // Эталон — та нумерация, которой записаны зачала Типикона.
      expect(resolveEditionCodes(const [], available), ["cs-eliz"]);
    });

    test("выбор читателя уважается", () {
      expect(resolveEditionCodes(["grc-lxx-pat"], available), ["grc-lxx-pat"]);
    });

    test("исчезнувшее издание молча заменяется эталоном", () {
      // Издание могли убрать с сервера, а выбор читателя остался в настройках.
      expect(resolveEditionCodes(["ro-1688"], available), ["cs-eliz"]);
    });

    test("китайское издание сохраняется в выборе с системными шрифтами", () {
      expect(resolveEditionCodes(["zh-1910"], available), ["zh-1910"]);
    });

    test("без эталона берётся первое доступное издание", () {
      final noReference = BibleEditionList([
        edition("zh-1910", "zh"),
        edition("la-vulgata", "la"),
      ]);

      expect(resolveEditionCodes(const [], noReference), ["zh-1910"]);
    });

    test(
      "издание с другим письмом доступно; пустой каталог не роняет выбор",
      () {
        // Пустой набор сервер понимает как «все публичные издания».
        final unreadable = BibleEditionList([edition("zh-1910", "zh")]);

        expect(resolveEditionCodes(const [], unreadable), ["zh-1910"]);
        expect(
          resolveEditionCodes(const [], const BibleEditionList([])),
          isEmpty,
        );
      },
    );
  });

  group("шрифт по письму издания", () {
    test("церковнославянскому и валашскому даётся Monomakh", () {
      // Гражданским шрифтом их не показать: в нём нет ни титла, ни юса.
      expect(bibleFontFamily("cu"), "Monomakh");
      expect(bibleFontFamily("ro_cyr"), "Monomakh");
    });

    test("греческому и латыни — OldStandard", () {
      expect(bibleFontFamily("grc"), "OldStandard");
      expect(bibleFontFamily("la"), "OldStandard");
    });

    test("латиница показуема, какой бы язык на ней ни был написан", () {
      // Румынская синодальная 1914 объявляет письмо `ro`, и список, собранный по
      // догадке, её вычеркнул: OldStandard рисует латиницу без труда, а издание
      // пропало из выбора. Нашлось только на устройстве.
      expect(canRenderEdition(edition("ro-1914", "ro")), isTrue);
      expect(bibleFontFamily("ro"), "OldStandard");
    });

    test("другие письменности доступны через системный подбор шрифтов", () {
      for (final language in ['zh', 'ka', 'hy', 'ar', 'he', 'ja']) {
        final item = edition('$language-test', language);
        expect(canRenderEdition(item), isTrue);
        expect(editionUnavailableReason(item), isNull);
        expect(resolveEditionCodes([item.code], BibleEditionList([item])), [
          item.code,
        ]);
      }
    });
  });
}
