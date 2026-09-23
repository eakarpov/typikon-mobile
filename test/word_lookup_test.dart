import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/components/reading_markdown.dart';
import 'package:typikon/components/selection_menu.dart';
import 'package:typikon/components/verse_list.dart';
import 'package:typikon/dto/pericope.dart';
import 'package:typikon/dto/reference.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/utils/lexeme_labels.dart';
import 'package:typikon/utils/selected_word.dart';

// Ударение и разбор по выделенному слову. Ответы ручки — настоящие, сняты с
// typikon.info 2026-09-23 и укорочены.

WordAccents _parse(String body) => WordAccents.fromJson(jsonDecode(body));

void main() {
  group("слово из выделения", () {
    test("препинание по краям снимается", () {
      expect(selectedWord("землю,"), "землю");
      expect(selectedWord(" «Го́споди!» "), "Го́споди");
      expect(selectedWord("(спасе)"), "спасе");
    });

    test("надстрочное остаётся частью слова", () {
      expect(selectedWord("бг҃ъ."), "бг҃ъ");
      expect(selectedWord("ѿ-нюдуже"), "ѿ-нюдуже");
    });

    test("два слова — уже не слово", () {
      expect(selectedWord("Благословен Бог"), isNull);
      expect(selectedWord("землю,и"), isNull);
    });

    test("не кириллица и пустое — не слово", () {
      expect(selectedWord("Amen"), isNull);
      expect(selectedWord("123"), isNull);
      expect(selectedWord(" , "), isNull);
      expect(selectedWord(null), isNull);
    });

    test("титло узнаётся", () {
      expect(hasTitlo("бг҃ъ"), isTrue);
      expect(hasTitlo("бо́гъ"), isFalse);
    });
  });

  group("сравнение написаний", () {
    test("словарное написание совпадает с набранным", () {
      // Словарь пишет «хрісто́съ», а в тексте — «Христосъ».
      expect(spellingKey("хрісто́съ"), spellingKey("Христосъ"));
      expect(spellingKey("мѣ́сто"), spellingKey("место"));
    });

    test("разные слова не совпадают", () {
      expect(spellingKey("земля́"), isNot(spellingKey("землянъ")));
    });
  });

  group("разбор словами", () {
    test("падеж и число", () {
      expect(formParseLabel(["sg", "acc"]), "ед. вин.");
    });

    test("совпавшие формы — через косую, лица — одним числом", () {
      expect(formParseLabel(["indic", "aor", "sg", "2p/3p"]), "изъяв. аорист ед. 2/3 л.");
      expect(formParseLabel(["plen/brev", "pl", "gen/loc"]), "полн./кратк. мн. род./мест.");
    });

    test("незнакомая помета — как есть", () {
      expect(formParseLabel(["sg", "xyz"]), "ед. xyz");
    });
  });

  group("ответ ручки ударений", () {
    test("редкое ударение не выдаётся за второе", () {
      // «Зе́млю» — 1639 раз, «землю́» — дважды. Словарь знает обе, но выбора
      // тут нет.
      final accents = _parse('''
        {"word":"землю","known":true,"agree":true,
         "corpus":[{"vowel":0,"spelling":"зе́млю","count":1639,"share":0.9988},
                   {"vowel":1,"spelling":"землю́","count":2,"share":0.0012}],
         "chants":[{"vowel":0,"spelling":"зе́млю","count":1911,"share":0.9995},
                   {"vowel":1,"spelling":"землю́","count":1,"share":0.0005}],
         "lexicon":[{"vowel":0,"spelling":"зе́млю","lexeme":"земля́","properties":"sg,acc"},
                    {"vowel":1,"spelling":"землю́","lexeme":"земля́","properties":"sg,acc"}]}
      ''');

      expect(accents.isDisputed, isFalse);
      expect(accents.stresses.single.spelling, "зе́млю");
      expect(accents.lexicon.first.parses, [["sg", "acc"]]);
    });

    test("вария и оксия на одной гласной — одно ударение", () {
      final accents = _parse('''
        {"word":"земля","known":true,"agree":true,
         "corpus":[{"vowel":1,"spelling":"земля́","count":258,"share":0.93},
                   {"vowel":1,"spelling":"земля̀","count":18,"share":0.07}],
         "chants":[], "lexicon":[]}
      ''');

      final stress = accents.stresses.single;
      expect(stress.spelling, "земля́");
      expect(stress.readingsShare, closeTo(1.0, 0.001));
      expect(stress.chantsShare, isNull);
    });

    test("спорное: чтения и песнопения расходятся", () {
      final accents = _parse('''
        {"word":"спасе","known":true,"agree":false,
         "corpus":[{"vowel":1,"spelling":"спасе́","count":50,"share":0.4464},
                   {"vowel":0,"spelling":"спа́се","count":46,"share":0.4107},
                   {"vowel":1,"spelling":"спасѐ","count":16,"share":0.1429}],
         "chants":[{"vowel":0,"spelling":"спа́се","count":2024,"share":0.8148},
                   {"vowel":1,"spelling":"спасе́","count":460,"share":0.1852}],
         "lexicon":[{"vowel":1,"spelling":"спасе́","lexeme":"спасти́","properties":"indic,aor,sg,2p/3p"},
                    {"vowel":0,"spelling":"спа́се","lexeme":"спа́съ","properties":"sg,voc"}]}
      ''');

      expect(accents.isDisputed, isTrue);
      expect(accents.stresses.map((s) => s.spelling), ["спа́се", "спасе́"]);
      // Вария сложена с оксией той же гласной.
      expect(accents.stresses.last.readingsShare, closeTo(0.5893, 0.001));
    });

    test("несколько разборов одного написания", () {
      final accents = _parse('''
        {"word":"Господи","known":true,"agree":true,"corpus":[],"chants":[],
         "lexicon":[{"vowel":0,"spelling":"го́споди","lexeme":"госпо́дь","properties":"sg,loc|pl,nom"}]}
      ''');

      expect(accents.lexicon.single.parses, [["sg", "loc"], ["pl", "nom"]]);
      // Текстов о слове нет — словарное ударение показывается.
      expect(accents.stresses.single.inLexicon, isTrue);
    });

    test("неизвестное слово", () {
      final accents = _parse(
          '{"word":"гдеже","known":false,"agree":null,"corpus":[],"chants":[],"lexicon":[]}');

      expect(accents.known, isFalse);
      expect(accents.agree, isNull);
      expect(accents.stresses, isEmpty);
    });
  });

  group("меню выделения", () {
    Future<void> pumpReading(WidgetTester tester, {required bool signedIn}) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SelectionMenu(
              enabled: signedIn,
              textId: "t1",
              containers: const [
                TextContainer.paragraph(paragraphIndex: 0, text: "Благословен Бог наш"),
              ],
              child: const Center(
                child: FusionTextWidgets(
                  text: "Благословен Бог наш",
                  footnotes: [],
                  fontFamily: "OldStandard",
                ),
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets("не вошедшему — ударение и копирование", (tester) async {
      await pumpReading(tester, signedIn: false);
      await tester.longPress(find.byType(RichText).first);
      await tester.pumpAndSettle();

      expect(find.text("Ударение и разбор"), findsOneWidget);
      expect(find.text("Copy"), findsOneWidget);
      expect(find.text("Сообщить об ошибке"), findsNothing);
    });

    testWidgets("вошедшему копирование не пропадает за нашими пунктами", (tester) async {
      await pumpReading(tester, signedIn: true);
      await tester.longPress(find.byType(RichText).first);
      await tester.pumpAndSettle();

      expect(find.text("Ударение и разбор"), findsOneWidget);
      expect(find.text("Copy"), findsOneWidget);
      // Кнопок больше, чем помещается в строку: остальные — под «ещё».
      final more = find.byTooltip("More");
      if (more.evaluate().isNotEmpty) {
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      expect(find.text("Сообщить об ошибке"), findsOneWidget);
      expect(find.text("Добавить заметку"), findsOneWidget);
    });
  });

  // Библия, каноны, акафисты, молитвы: ударение есть, заметок и сообщений об
  // ошибке нет — они пишутся на тексты библиотеки, а не на главу или песнопение.
  group("меню без заметок", () {
    Future<void> pump(WidgetTester tester, Widget text) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: Scaffold(body: Center(child: SelectionMenu.wordsOnly(child: text))),
        ),
      ));
    }

    Future<void> expectWordMenu(WidgetTester tester, Finder target) async {
      await tester.longPress(target);
      await tester.pumpAndSettle();

      expect(find.text("Ударение и разбор"), findsOneWidget);
      expect(find.text("Copy"), findsOneWidget);
      expect(find.text("Сообщить об ошибке"), findsNothing);
      expect(find.text("Добавить заметку"), findsNothing);
    }

    testWidgets("стихи Библии", (tester) async {
      await pump(
        tester,
        const VerseListView(
          verses: [PericopeVerse(chapter: 1, verse: 1, content: "Въ началѣ бѣ слово")],
          fontSize: 18.0,
        ),
      );
      await expectWordMenu(tester, find.byType(RichText).first);
    });

    testWidgets("размеченный текст", (tester) async {
      await pump(tester, const ReadingMarkdown("Благословен **Бог** наш", scrollable: false));
      await expectWordMenu(tester, find.byType(RichText).first);
    });

    testWidgets("строка песнопения", (tester) async {
      await pump(tester, const Text("Радуйся, Невесто неневестная"));
      await expectWordMenu(tester, find.text("Радуйся, Невесто неневестная"));
    });
  });
}
