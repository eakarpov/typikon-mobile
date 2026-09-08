import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/note_sheet.dart';
import 'package:typikon/dto/pomyannik.dart';

// Лист записки. Всё здесь про одно: не выдать нашу догадку за книжное чтение.
//
// Человек, принявший наш именительный падеж за проверенный родительный, отдаст
// священнику ошибку, которой сам бы не сделал, — и узнает об этом у аналоя.

final Vocabulary vocabulary = Vocabulary.fromJson(jsonDecode('''
  {"ranks": [
    {"key": "ierey", "label": "иерей", "genitive": "иерея", "cs": "їере́а",
     "feminine": null, "only": null},
    {"key": "bolyashchiy", "label": "болящий", "genitive": "болящего", "cs": null,
     "feminine": {"label": "болящая", "genitive": "болящую", "cs": null},
     "only": "living"}
  ], "noteKinds": [], "limits": {}}
'''));

NoteSheet sheet(String names) => NoteSheet.fromJson(jsonDecode(
    '{"kind":{"key":"proskomidia","label":"Обедня","about":"both","days":0,"note":""},'
    '"span":null,"names":$names}'));

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets("склонённое имя печатается с прописной", (tester) async {
    // Словарь хранит леммы строчными, и склонение выдаёт их такими же. В записке
    // же имя пишут с прописной: это имя человека, а не слово из словаря.
    await pump(
      tester,
      NoteSheetView(
        sheet: sheet('[{"name":"Николай","slavonic":"нїкола́а",'
            '"slavonicSource":"lexicon","kind":"departed"}]'),
        vocabulary: vocabulary,
      ),
    );

    expect(find.text("Нїкола́а"), findsOneWidget);
  });

  testWidgets("несклонённое имя названо под листом", (tester) async {
    // Молча выдать именительный за родительный — худшее, что здесь возможно.
    final list = sheet('[{"name":"Свiтлана","slavonic":"свiтлана",'
        '"slavonicSource":"accents","kind":"living"}]');

    await pump(
      tester,
      Column(children: [
        NoteSheetView(sheet: list, vocabulary: vocabulary),
        NoteSheetCaveats(sheet: list, vocabulary: vocabulary),
      ]),
    );

    expect(find.textContaining("падеж у них остался прежним"), findsOneWidget);
    expect(find.textContaining("Свiтлана"), findsWidgets);
  });

  testWidgets("склонённое имя оговорки не вызывает", (tester) async {
    final list = sheet('[{"name":"Николай","slavonic":"нїкола́а",'
        '"slavonicSource":"lexicon","kind":"departed"}]');

    await pump(tester, NoteSheetCaveats(sheet: list, vocabulary: vocabulary));

    expect(find.textContaining("падеж"), findsNothing);
  });

  testWidgets("помета без книжного начертания ставится гражданкой — и об этом сказано",
      (tester) async {
    // `cs: null` значит «книгой не подтверждено». Подставить сюда гражданку молча
    // значило бы выдать её за церковнославянское написание.
    final list = sheet('[{"name":"Николай","slavonic":"нїкола́а",'
        '"slavonicSource":"lexicon","kind":"living","rank":"bolyashchiy","sex":"m"}]');

    await pump(
      tester,
      Column(children: [
        NoteSheetView(sheet: list, vocabulary: vocabulary),
        NoteSheetCaveats(sheet: list, vocabulary: vocabulary),
      ]),
    );

    expect(find.text("болящего Нїкола́а"), findsOneWidget);
    expect(find.textContaining("стоят гражданкой"), findsOneWidget);
  });

  testWidgets("подтверждённая помета печатается по-церковнославянски и молчит", (tester) async {
    final list = sheet('[{"name":"Николай","slavonic":"нїкола́а",'
        '"slavonicSource":"lexicon","kind":"departed","rank":"ierey","sex":"m"}]');

    await pump(
      tester,
      Column(children: [
        NoteSheetView(sheet: list, vocabulary: vocabulary),
        NoteSheetCaveats(sheet: list, vocabulary: vocabulary),
      ]),
    );

    expect(find.text("їере́а Нїкола́а"), findsOneWidget);
    expect(find.textContaining("гражданкой"), findsNothing);
  });

  testWidgets("лист набран шрифтом, в котором эти знаки есть", (tester) async {
    // Проверено по таблицам кодировки самих шрифтов: в OldStandard нет ни креста
    // U+2626, ни узкого ᲂ U+1C82 из «ᲂу҆поко́енїи», а в Monomakh есть оба. Набранный
    // не тем шрифтом заголовок осыплется квадратами, и увидит это только тот, кто
    // посмотрит на экран.
    await pump(
      tester,
      NoteSheetView(
        sheet: sheet('[{"name":"Николай","slavonic":"нїкола́а",'
            '"slavonicSource":"lexicon","kind":"departed"}]'),
        vocabulary: vocabulary,
      ),
    );

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.fontFamily, "Monomakh", reason: "«${text.data}» набрано не тем шрифтом");
    }
  });

  testWidgets("крест снимается", (tester) async {
    // Лист с крестом не выбрасывают, а сжигают. Кто печатает записку дома и не
    // хочет этой заботы, вправе крест не ставить.
    final list = sheet('[{"name":"Анна","slavonic":"а́нны",'
        '"slavonicSource":"lexicon","kind":"living"}]');

    await pump(tester, NoteSheetView(sheet: list, vocabulary: vocabulary));
    expect(find.text("☦"), findsOneWidget);

    await pump(tester, NoteSheetView(sheet: list, vocabulary: vocabulary, cross: false));
    expect(find.text("☦"), findsNothing);
  });

  testWidgets("заголовки разделов церковнославянские", (tester) async {
    await pump(
      tester,
      NoteSheetView(
        sheet: sheet('[{"name":"Анна","slavonic":"а́нны","slavonicSource":"lexicon",'
            '"kind":"living"},{"name":"Николай","slavonic":"нїкола́а",'
            '"slavonicSource":"lexicon","kind":"departed"}]'),
        vocabulary: vocabulary,
      ),
    );

    expect(find.text("ѡ҆ здра́вїи"), findsOneWidget);
    expect(find.text("ѡ҆ ᲂу҆поко́енїи"), findsOneWidget);
  });
}
