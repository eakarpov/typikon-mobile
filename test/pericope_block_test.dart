import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/pericope_block.dart';
import 'package:typikon/dto/pericope.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

/// Зачало бывает разорванным и переходящим через границу главы, а глава Библии
/// показывается по одной. Поэтому «начало» и «конец» определяются сверкой с
/// самими границами, а не счётом кусков на экране: считай мы куски, читатель,
/// открывший вторую главу зачала, увидел бы «Начало зачала» там, где зачало уже
/// идёт с предыдущей страницы.
///
/// Зачало здесь настоящее: Мф. 6:31–34 и 7:9–11 — то самое, что стоит в
/// понедельник 2-й седмицы по Пятидесятнице.
const List<PericopeRange> ranges = [
  PericopeRange(chapterFrom: 6, verseFrom: 31, chapterTo: 6, verseTo: 34),
  PericopeRange(chapterFrom: 7, verseFrom: 9, chapterTo: 7, verseTo: 11),
];

List<PericopeVerse> chapterVerses(int chapter, int from, int to) => [
      for (var verse = from; verse <= to; verse++)
        PericopeVerse(chapter: chapter, verse: verse, content: "стих $chapter:$verse"),
    ];

Future<void> pumpChapter(WidgetTester tester, List<PericopeVerse> verses) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());

  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: buildPericopeBlocks(
              tester.element(find.byType(Scaffold)),
              verses: verses,
              ranges: ranges,
              fontSize: 16.0,
              fontFamily: "OldStandard",
              rangesLabel: "гл. 6, ст. 31–34; гл. 7, ст. 9–11",
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets("в первой главе зачало начинается, но не кончается", (tester) async {
    // Шестая глава несёт начало зачала; конец его — в седьмой.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await pumpChapter(tester, chapterVerses(6, 28, 36));

    expect(find.textContaining("Начало зачала"), findsOneWidget);
    expect(find.text("Продолжение ниже"), findsOneWidget);
    expect(find.text("Конец зачала"), findsNothing);
  });

  testWidgets("во второй главе зачало кончается, но не начинается", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await pumpChapter(tester, chapterVerses(7, 6, 14));

    expect(find.text("Зачало, продолжение"), findsOneWidget);
    expect(find.text("Конец зачала"), findsOneWidget);
    expect(find.textContaining("Начало зачала"), findsNothing);
  });

  testWidgets("подпись начала называет границы словами", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await pumpChapter(tester, chapterVerses(6, 28, 36));

    expect(find.text("Начало зачала (гл. 6, ст. 31–34; гл. 7, ст. 9–11)"), findsOneWidget);
  });

  testWidgets("стихи вне зачала остаются на месте", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await pumpChapter(tester, chapterVerses(6, 28, 36));

    // Глава показывается целиком: подсвечивается зачало, а не вырезается.
    // findRichText обязателен: стихи рисуются одним RichText со спанами, и
    // обычный поиск по тексту их не видит.
    expect(find.textContaining("стих 6:29", findRichText: true), findsOneWidget);
    expect(find.textContaining("стих 6:36", findRichText: true), findsOneWidget);
  });

  testWidgets("без границ подсветки нет вовсе", (tester) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());

    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: buildPericopeBlocks(
                context,
                verses: chapterVerses(6, 1, 3),
                ranges: const [],
                fontSize: 16.0,
                fontFamily: "OldStandard",
                rangesLabel: "",
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.textContaining("зачал"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
