import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/domain/psalter.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/pages/psalter_serial_page.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/psalter_serial_bookmark.dart';
import 'package:typikon/store/rootReducer.dart';

// «Псалтирь подряд»: открывается с закладки, помнит место при прокрутке,
// листается кнопкой «Псалом N →», после Пс 151 — честный финал.

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
              content: "Стих $i. Благословлю Господа на всякое время, "
                  "хвала моя в устах моих. ",
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
        return Future<BibleChapter>.value(chapter(psalm, 60));
      };
}

/// Приложение, в котором /psalter/serial ведёт на тот же экран с подменённым
/// загрузчиком — листание и финал идут через настоящий pushReplacement.
Future<List<String>> pumpSerial(
  WidgetTester tester, {
  int? chapter,
  RecordingLoader? loader,
}) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  final effective = loader ?? RecordingLoader();
  final pushed = <String>[];
  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      onGenerateRoute: (settings) {
        pushed.add(settings.name ?? "");
        if (settings.name == "/psalter/serial") {
          final arg = settings.arguments;
          return MaterialPageRoute(
            builder: (_) => PsalterSerialPage(
              chapter: arg is int ? arg : chapter,
              loadChapter: effective.load,
            ),
          );
        }
        return null;
      },
      home: PsalterSerialPage(chapter: chapter, loadChapter: effective.load),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return pushed;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets("без аргумента открывается с закладки", (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "psalter:serial": '{"chapter": 5, "verse": 3}',
    });
    final loader = RecordingLoader();
    await pumpSerial(tester, loader: loader);

    expect(loader.calls, <int>[5]);
    expect(find.textContaining("Псалом 5"), findsOneWidget);
  });

  testWidgets("без аргумента и без закладки — с первого псалма", (tester) async {
    final loader = RecordingLoader();
    await pumpSerial(tester, loader: loader);

    expect(loader.calls, <int>[1]);
    expect(find.textContaining("Псалом 1"), findsOneWidget);
  });

  testWidgets("с аргументом открывает названный псалом с начала",
      (tester) async {
    final loader = RecordingLoader();
    await pumpSerial(tester, chapter: 9, loader: loader);

    expect(loader.calls, <int>[9]);
    expect(find.textContaining("Псалом 9"), findsOneWidget);
  });

  testWidgets("прокрутка запоминает закладку {псалом, стих}", (tester) async {
    final loader = RecordingLoader();
    await pumpSerial(tester, chapter: 5, loader: loader);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pump(const Duration(seconds: 3)); // дебаунс записи

    final saved = await getPsalterSerialBookmark();
    expect(saved, isNotNull);
    expect(saved!.chapter, 5);
    expect(saved.verse, greaterThan(1));
  });

  testWidgets("листание: Пс 150 → «Псалом 151 →» → финал → «Начать сначала»",
      (tester) async {
    final loader = RecordingLoader();
    await pumpSerial(tester, chapter: 150, loader: loader);

    await tester.scrollUntilVisible(
        find.text("Псалом 151 →"), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text("Псалом 151 →"));
    await tester.pumpAndSettle();

    expect(loader.calls.last, 151);
    expect(find.textContaining("Псалом 151"), findsWidgets);

    await tester.scrollUntilVisible(
        find.text("Завершить чтение →"), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text("Завершить чтение →"));
    await tester.pumpAndSettle();

    expect(find.text("Псалтирь прочитана"), findsOneWidget);

    // «Начать сначала» сбрасывает закладку и открывает Пс 1.
    await savePsalterSerialBookmark(151, 7);
    await tester.tap(find.text("Начать сначала"));
    await tester.pumpAndSettle();

    expect(await getPsalterSerialBookmark(), isNull);
    expect(loader.calls.last, 1);
  });

  testWidgets("финал честный: название и пояснение, без кнопок листания",
      (tester) async {
    await pumpSerial(tester, chapter: lastPsalm + 2);

    expect(find.text("Псалтирь прочитана"), findsOneWidget);
    expect(find.textContaining("Пс 151"), findsWidgets);
    expect(find.text("Начать сначала"), findsOneWidget);
    expect(find.textContaining("→"), findsNothing);
  });
}
