import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/bible_parallel_view.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

/// Единственная ошибка параллельного вида, которую нельзя поймать на данных: она
/// возникает при рисовании. Пропущенная строка выглядит не как ошибка, а как
/// наша недоработка — читатель решит, что стих мы потеряли, тогда как его не
/// печатает само издание.
///
/// Фикстура настоящая: Пс. 9 в славянском и румынском изданиях. Надписания
/// псалма румынское издание не печатает, а дальше вся глава идёт у него со
/// сдвинутым на единицу номером.
const String psalm9 = '''
{
  "book": {"id": "psaltir", "name": "Псалтирь", "abbr": "Пс", "section": "teaching", "inCanon": true},
  "chapter": 9,
  "editions": [
    {"code": "cs-eliz", "title": "Елизаветинская", "shortTitle": "ЦС", "language": "cu",
     "languageCode": "cs", "versification": "sla-lxx", "year": 1751, "sourceUrl": null},
    {"code": "ro-1688", "title": "Сфънта Скриптура", "shortTitle": "РУМ", "language": "ro_cyr",
     "languageCode": "ro", "versification": "ro-1688", "year": 1688, "sourceUrl": null}
  ],
  "verses": [
    {"canonRef": "psaltir.9.1", "verse": 1, "editions": [
      {"id": "a1", "canonRef": "psaltir.9.1", "chapter": 9, "verse": 1,
       "editionChapter": 9, "editionVerse": 1, "content": "Въ конецъ"},
      null
    ]},
    {"canonRef": "psaltir.9.2", "verse": 2, "editions": [
      {"id": "a2", "canonRef": "psaltir.9.2", "chapter": 9, "verse": 2,
       "editionChapter": 9, "editionVerse": 2, "content": "Исповемся"},
      {"id": "b2", "canonRef": "psaltir.9.2", "chapter": 9, "verse": 2,
       "editionChapter": 9, "editionVerse": 1, "content": "Мэрturisi-voi"}
    ]}
  ]
}
''';

Future<void> pumpView(WidgetTester tester) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());

  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BibleParallelView(
            chapter: BibleChapter.fromJson(jsonDecode(psalm9)),
            fontSize: 16.0,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets("пропуск издания рисуется, а не пропускается", (tester) async {
    await pumpView(tester);

    expect(find.text("в этом издании стиха нет"), findsOneWidget);
  });

  testWidgets("подписи изданий стоят у каждого стиха", (tester) async {
    await pumpView(tester);

    // Два стиха на два издания: подпись обязана быть у каждой строки, иначе в
    // чередовании не разобрать, где чьё.
    expect(find.text("ЦС"), findsNWidgets(2));
    expect(find.text("РУМ"), findsNWidgets(2));
  });

  testWidgets("родной номер подписывается только там, где он разошёлся", (tester) async {
    await pumpView(tester);

    // У румынского второй канонический стих напечатан первым — по этому номеру
    // его и ищут в бумажной книге.
    expect(find.text("9:1"), findsOneWidget);
    // У славянского обе нумерации совпадают, и лишней подписи быть не должно.
    expect(find.text("9:2"), findsNothing);
  });

  testWidgets("канонический номер стоит один на блок, а не у каждой строки", (tester) async {
    await pumpView(tester);

    expect(find.text("1"), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
  });

  testWidgets("текст обоих изданий доходит до экрана", (tester) async {
    await pumpView(tester);

    expect(find.text("Въ конецъ"), findsOneWidget);
    expect(find.text("Исповемся"), findsOneWidget);
    expect(find.text("Мэрturisi-voi"), findsOneWidget);
  });

  testWidgets("вид не роняет исключений", (tester) async {
    await pumpView(tester);

    expect(tester.takeException(), isNull);
  });
}
