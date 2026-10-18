import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/domain/psalter.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/pages/kathisma_page.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

// Чтение кафизмы: псалмы диапазона подряд одним скроллом, разделители после
// правильных псалмов (у 17-й — после правильных стихов Пс 118), окончание
// кафизмы в конце. Слой загрузки главы подменён: сеть в тесте не нужна.

const _book = BibleBook(
    id: "psaltir", name: "Псалтирь", abbr: "Пс", section: "teaching", inCanon: true);
const _edition = BibleEdition(
  code: "cs-eliz",
  title: "Елизаветинская",
  shortTitle: "ЦС",
  language: "cu",
  languageCode: "cs",
  versification: "sla-lxx",
);

BibleChapter chapter(int number, int verseCount) {
  return BibleChapter(
    book: _book,
    chapter: number,
    editions: const <BibleEdition>[_edition],
    rows: <BibleRow>[
      for (var i = 1; i <= verseCount; i++)
        BibleRow(
          canonRef: "psaltir.$number.$i",
          verse: i,
          cells: <BibleCell?>[
            BibleCell(
              id: "cell-$number-$i",
              canonRef: "psaltir.$number.$i",
              chapter: number,
              verse: i,
              editionChapter: number,
              editionVerse: i,
              content: "Стих $i. Благословлю Господа на всякое время. ",
            ),
          ],
        ),
    ],
  );
}

class RecordingLoader {
  final calls = <int>[];

  Future<BibleChapter> Function(int) get load => (int psalm) {
        calls.add(psalm);
        return Future<BibleChapter>.value(chapter(psalm, 6));
      };
}

Future<void> pumpKathisma(
  WidgetTester tester,
  int number,
  RecordingLoader loader,
) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: KathismaPage(number: number, loadChapter: loader.load),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

/// Текстовые строки экрана в порядке дерева — подписи псалмов и разделители
/// идут в том порядке, в каком стоят на экране.
List<String> visibleTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets("6-я кафизма: псалмы 37–45, разделители после 39 и 42",
      (tester) async {
    final loader = RecordingLoader();
    await pumpKathisma(tester, 6, loader);

    // Параллельная загрузка: все девять псалмов запрошены, каждый по разу.
    expect(loader.calls, <int>[37, 38, 39, 40, 41, 42, 43, 44, 45]);

    for (var psalm = 37; psalm <= 45; psalm++) {
      expect(find.text("Псалом $psalm"), findsOneWidget);
    }

    // Два разделителя между тремя статьями и окончание кафизмы.
    expect(find.text(statiaBreak), findsNWidgets(2));
    expect(find.text(kathismaEnd), findsOneWidget);
    expect(find.text(psalmodyEnd), findsNothing);

    // Порядок: разделитель после третьей статьи стоит между Пс 39 и Пс 40,
    // второй — между Пс 42 и Пс 43, окончание — после последнего псалма.
    final texts = visibleTexts(tester);
    final firstBreak = texts.indexOf(statiaBreak);
    final secondBreak = texts.lastIndexOf(statiaBreak);
    expect(firstBreak, greaterThan(texts.indexOf("Псалом 39")));
    expect(firstBreak, lessThan(texts.indexOf("Псалом 40")));
    expect(secondBreak, greaterThan(texts.indexOf("Псалом 42")));
    expect(secondBreak, lessThan(texts.indexOf("Псалом 43")));
    expect(texts.indexOf(kathismaEnd), greaterThan(texts.indexOf("Псалом 45")));
  });

  testWidgets("17-я кафизма: Пс 118 один, разделители «Слава, и ныне» после стихов",
      (tester) async {
    // Читаем всякую главу как 176 стихов, чтобы срезы статей были видны.
    final counting = RecordingLoader();
    Future<BibleChapter> load118(int psalm) {
      counting.calls.add(psalm);
      return Future<BibleChapter>.value(chapter(118, 176));
    }

    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: KathismaPage(number: 17, loadChapter: load118),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Три статьи из одного псалма — глава запрошена один раз.
    expect(counting.calls, <int>[118]);
    expect(find.text("Псалом 118"), findsOneWidget);

    // Разделители 17-й — «Слава, и ныне:», их два; обычного разделителя нет.
    expect(find.text(psalmodyEnd), findsNWidgets(2));
    expect(find.text(statiaBreak), findsNothing);
    expect(find.text(kathismaEnd), findsOneWidget);
  });

  testWidgets("Пс 151: один псалом без разделителей и окончания",
      (tester) async {
    final loader = RecordingLoader();
    await pumpKathisma(tester, psalm151, loader);

    expect(loader.calls, <int>[151]);
    expect(find.text("Псалом 151 (дополнительный)"), findsOneWidget);
    expect(find.text("Псалом 151"), findsOneWidget);
    expect(find.text(statiaBreak), findsNothing);
    expect(find.text(psalmodyEnd), findsNothing);
    expect(find.text(kathismaEnd), findsNothing);
  });

  testWidgets("1-я кафизма: восемь псалмов, два разделителя", (tester) async {
    final loader = RecordingLoader();
    await pumpKathisma(tester, 1, loader);

    expect(loader.calls, <int>[1, 2, 3, 4, 5, 6, 7, 8]);
    expect(find.text(statiaBreak), findsNWidgets(2));
    expect(find.text(kathismaEnd), findsOneWidget);
  });
}
