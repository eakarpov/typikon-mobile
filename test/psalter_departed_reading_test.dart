import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/components/named_prayer_block.dart';
import 'package:typikon/domain/psalter.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/dto/prayer_text.dart';
import 'package:typikon/dto/posledovanie.dart';
import 'package:typikon/pages/kathisma_page.dart';
import 'package:typikon/pages/psalter_serial_page.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/psalter_prayers.dart';
import 'package:typikon/store/rootReducer.dart';

// Поминальное чтение Псалтири: блок молитв встаёт после всякой славы кафизмы
// (об усопших — после «Слава», о живых — после «И ныне»), а в «подряд» —
// один блок на границе кафизмы. Плашки честные: снимок протух, сети нет,
// вход не сделан. Загрузчики подменены: сеть в тесте не нужна.

const _book = BibleBook(
  id: "psaltir",
  name: "Псалтирь",
  abbr: "Пс",
  section: "teaching",
  inCanon: true,
);
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
    return Future<BibleChapter>.value(chapter(psalm, psalm == 118 ? 176 : 6));
  };
}

const _departedPrayer = NamedPrayer(id: "d1", text: "Молитва об усопших.");
const _livingPrayer = NamedPrayer(id: "l1", text: "Молитва о живых.");

const _withPrayers = PsalterNamedPrayers(
  departed: <NamedPrayer>[_departedPrayer],
  living: <NamedPrayer>[_livingPrayer],
);

Future<Posledovanie> endingFor(int n) async => Posledovanie(
  rows: [
    const PosledovanieRow(label: 'Трисвятое по Отче наш', text: 'Святый Боже'),
    PosledovanieRow(
      label: 'Тропари по $n-й кафизме',
      text: 'Тропарь кафизмы $n',
    ),
    PosledovanieRow(
      label: 'Молитва по $n-й кафизме',
      text: 'Молитва кафизмы $n',
    ),
  ],
);

Future<PsalterNamedPrayers> Function(String) prayersOf(
  PsalterNamedPrayers prayers,
) =>
    (_) async => prayers;

/// Текстовые строки экрана в порядке дерева.
List<String> visibleTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
}

void orderBefore(List<String> texts, String first, String second) {
  final a = texts.indexOf(first);
  final b = texts.indexOf(second);
  expect(a, isNot(-1), reason: "«$first» не найдено");
  expect(b, isNot(-1), reason: "«$second» не найдено");
  expect(a, lessThan(b), reason: "«$first» должно стоять раньше «$second»");
}

Future<void> pumpDepartedKathisma(
  WidgetTester tester, {
  required int number,
  required RecordingLoader loader,
  required Future<PsalterNamedPrayers> Function(String gender) prayersLoader,
}) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  await tester.pumpWidget(
    StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: KathismaPage(
          number: number,
          departed: true,
          loadChapter: loader.load,
          prayersLoader: prayersLoader,
          endingLoader: endingFor,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<List<Object?>> pumpDepartedSerial(
  WidgetTester tester, {
  required int chapter,
  required RecordingLoader loader,
  required Future<PsalterNamedPrayers> Function(String gender) prayersLoader,
}) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  final serialArgs = <Object?>[];
  await tester.pumpWidget(
    StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == "/psalter/serial") {
            serialArgs.add(settings.arguments);
            final target = parseSerialRouteArgument(settings.arguments);
            return MaterialPageRoute(
              builder: (_) => PsalterSerialPage(
                chapter: target?.chapter,
                departed: target?.departed ?? false,
                loadChapter: loader.load,
                prayersLoader: prayersLoader,
                endingLoader: endingFor,
              ),
            );
          }
          return null;
        },
        home: PsalterSerialPage(
          chapter: chapter,
          departed: true,
          loadChapter: loader.load,
          prayersLoader: prayersLoader,
          endingLoader: endingFor,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return serialArgs;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group("разбор аргументов маршрутов", () {
    test("кафизма: прежнее int и новое «N|d»", () {
      expect(parseKathismaRouteArgument(6)?.number, 6);
      expect(parseKathismaRouteArgument(6)?.departed, isFalse);
      expect(parseKathismaRouteArgument(151)?.number, 151);
      expect(parseKathismaRouteArgument("17|d")?.number, 17);
      expect(parseKathismaRouteArgument("17|d")?.departed, isTrue);
      expect(parseKathismaRouteArgument("17")?.departed, isFalse);
      expect(parseKathismaRouteArgument("17|x")?.departed, isFalse);
      expect(parseKathismaRouteArgument(0), isNull);
      expect(parseKathismaRouteArgument("21"), isNull);
      expect(parseKathismaRouteArgument("|d"), isNull);
      expect(parseKathismaRouteArgument("6|d|x"), isNull);
      expect(kathismaRouteArgument(6), 6);
      expect(kathismaRouteArgument(6, departed: true), "6|d");
    });

    test("serial: null, число, «d» и «N|d»", () {
      expect(parseSerialRouteArgument(null)?.chapter, isNull);
      expect(parseSerialRouteArgument(5)?.chapter, 5);
      expect(parseSerialRouteArgument("d")?.departed, isTrue);
      expect(parseSerialRouteArgument("d")?.chapter, isNull);
      expect(parseSerialRouteArgument("5|d")?.chapter, 5);
      expect(parseSerialRouteArgument("5|d")?.departed, isTrue);
      expect(parseSerialRouteArgument("abc"), isNull);
      expect(parseSerialRouteArgument("5|d|x"), isNull);
      expect(serialRouteArgument(), isNull);
      expect(serialRouteArgument(chapter: 5), 5);
      expect(serialRouteArgument(departed: true), "d");
      expect(serialRouteArgument(chapter: 5, departed: true), "5|d");
    });
  });

  group("кафизма в поминальном режиме", () {
    testWidgets('кнопка обновления имён заново загружает молитвы', (
      tester,
    ) async {
      var calls = 0;
      await pumpDepartedKathisma(
        tester,
        number: 1,
        loader: RecordingLoader(),
        prayersLoader: (_) async {
          calls++;
          return PsalterNamedPrayers(
            departed: [NamedPrayer(text: 'Обновление $calls')],
          );
        },
      );
      final button = find.text('Обновить имена').first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Обновление 2'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
    testWidgets('тропари видны до ответа сервера с именами', (tester) async {
      final pending = Completer<PsalterNamedPrayers>();
      await pumpDepartedKathisma(
        tester,
        number: 6,
        loader: RecordingLoader(),
        prayersLoader: (_) => pending.future,
      );
      expect(find.text('Тропарь кафизмы 6'), findsOneWidget);
      expect(find.textContaining('Со ду́хи пра́ведных'), findsNothing);
      expect(find.text('О живых:'), findsNothing);
      pending.complete(const PsalterNamedPrayers(signInNeeded: true));
      await tester.pump();
    });
    testWidgets("блок после всякой славы: слава → усопшие → и ныне → дальше", (
      tester,
    ) async {
      final loader = RecordingLoader();
      await pumpDepartedKathisma(
        tester,
        number: 6,
        loader: loader,
        prayersLoader: prayersOf(_withPrayers),
      );

      // Два разделителя — два блока.
      expect(find.text(statiaBreak), findsNothing);
      expect(find.text("О усопших:"), findsNWidgets(3));
      expect(find.text("О живых:"), findsNothing);
      expect(find.text("Молитва об усопших."), findsNWidgets(3));
      expect(find.text("Молитва о живых."), findsNothing);

      // Порядок внутри блока: разделитель, усопшие, живые, следующая статья.
      final texts = visibleTexts(tester);
      orderBefore(texts, "Слава Отцу и Сыну и Святому Духу.", "О усопших:");
      orderBefore(texts, "О усопших:", "Молитва об усопших.");
      orderBefore(
        texts,
        "Молитва об усопших.",
        "И ныне и присно и во веки веков. Аминь.",
      );
      orderBefore(texts, "Молитва об усопших.", "Псалом 40");
      // Второй разделитель — тоже со своим блоком (lastIndexOf: первый
      // «О усопших:» относится к первой славе).
      final secondBlock = texts.indexOf(
        "О усопших:",
        texts.indexOf("О усопших:") + 1,
      );
      expect(secondBlock, greaterThan(texts.indexOf("Псалом 42")));
      expect(secondBlock, lessThan(texts.indexOf("Псалом 43")));
      expect(
        texts.lastIndexOf("Молитва об усопших."),
        greaterThan(texts.indexOf("Псалом 43")),
      );
    });

    testWidgets("17-я кафизма: блок и после «Слава, и ныне»", (tester) async {
      final counting = RecordingLoader();
      Future<BibleChapter> load118(int psalm) {
        counting.calls.add(psalm);
        return Future<BibleChapter>.value(chapter(118, 176));
      }

      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: store,
          child: MaterialApp(
            home: KathismaPage(
              number: 17,
              departed: true,
              loadChapter: load118,
              prayersLoader: prayersOf(_withPrayers),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text(psalmodyEnd), findsNothing);
      expect(find.text("О усопших:"), findsNWidgets(3));
      expect(find.text(statiaBreak), findsNothing);
    });

    testWidgets("без молитв нет ни блока, ни плашек", (tester) async {
      final loader = RecordingLoader();
      await pumpDepartedKathisma(
        tester,
        number: 6,
        loader: loader,
        prayersLoader: prayersOf(const PsalterNamedPrayers()),
      );

      expect(find.text("О усопших:"), findsNothing);
      expect(find.text(namedPrayersStaleNotice), findsNothing);
      expect(find.text("Псалом 37"), findsOneWidget);
    });

    testWidgets("плашка «войдите» при отказе сессии, кафизма читается", (
      tester,
    ) async {
      final loader = RecordingLoader();
      await pumpDepartedKathisma(
        tester,
        number: 6,
        loader: loader,
        prayersLoader: prayersOf(const PsalterNamedPrayers(signInNeeded: true)),
      );

      expect(find.text(namedPrayersSignInNotice), findsOneWidget);
      expect(find.text("О усопших:"), findsNothing);
      expect(find.text("Псалом 37"), findsOneWidget);
      expect(find.text(statiaBreak), findsNWidgets(2));
    });

    testWidgets("плашка «нет сети» без снимка: молитв нет, кафизма цела", (
      tester,
    ) async {
      final loader = RecordingLoader();
      await pumpDepartedKathisma(
        tester,
        number: 6,
        loader: loader,
        prayersLoader: prayersOf(const PsalterNamedPrayers(unavailable: true)),
      );

      expect(find.text(namedPrayersUnavailableNotice), findsOneWidget);
      expect(find.text("О усопших:"), findsNothing);
      expect(find.text("Псалом 45"), findsOneWidget);
    });

    testWidgets("протухший снимок: молитвы есть, плашка — одна на кафизму", (
      tester,
    ) async {
      final loader = RecordingLoader();
      await pumpDepartedKathisma(
        tester,
        number: 6,
        loader: loader,
        prayersLoader: prayersOf(
          const PsalterNamedPrayers(
            departed: <NamedPrayer>[_departedPrayer],
            living: <NamedPrayer>[_livingPrayer],
            stale: true,
          ),
        ),
      );

      expect(find.text("Молитва об усопших."), findsNWidgets(3));
      expect(find.text(namedPrayersStaleNotice), findsOneWidget);
    });

    testWidgets("род молящегося передаётся загрузчику из rule_gender", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        "rule_gender": "f",
      });
      final loader = RecordingLoader();
      final genders = <String>[];
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: store,
          child: MaterialApp(
            home: KathismaPage(
              number: 6,
              departed: true,
              loadChapter: loader.load,
              prayersLoader: (gender) async {
                genders.add(gender);
                return _withPrayers;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(genders, <String>["f"]);
    });
  });

  group("«Подряд» в поминальном режиме", () {
    testWidgets("блок на границе кафизмы: Пс 8 — есть, Пс 9 — нет", (
      tester,
    ) async {
      final loader = RecordingLoader();
      final args = await pumpDepartedSerial(
        tester,
        chapter: 8,
        loader: loader,
        prayersLoader: prayersOf(_withPrayers),
      );

      // Пс 8 кончает 1-ю кафизму: блок стоит, плашек нет.
      expect(find.text("О усопших:"), findsOneWidget);
      expect(find.text("Молитва об усопших."), findsOneWidget);
      expect(find.text("Молитва о живых."), findsNothing);
      expect(find.text(namedPrayersStaleNotice), findsNothing);
      expect(find.textContaining("о усопших"), findsWidgets);

      // Листание держит режим: аргумент «9|d», и это всё ещё поминальное чтение.
      await tester.ensureVisible(find.text("Псалом 9 →"));
      await tester.tap(find.text("Псалом 9 →"));
      await tester.pumpAndSettle();

      expect(args.last, "9|d");
      expect(loader.calls.last, 9);
      expect(find.text("О усопших:"), findsNothing);
      expect(find.textContaining("о усопших"), findsWidgets);
    });

    testWidgets("граница 17-й кафизмы — после Пс 118", (tester) async {
      final loader = RecordingLoader();
      await pumpDepartedSerial(
        tester,
        chapter: 118,
        loader: loader,
        prayersLoader: prayersOf(_withPrayers),
      );

      expect(find.text("О усопших:"), findsNWidgets(3));
    });

    testWidgets("плашки на границе: нет сети и нет входа", (tester) async {
      final loader = RecordingLoader();
      await pumpDepartedSerial(
        tester,
        chapter: 8,
        loader: loader,
        prayersLoader: prayersOf(const PsalterNamedPrayers(unavailable: true)),
      );
      expect(find.text(namedPrayersUnavailableNotice), findsOneWidget);
      expect(find.text("О усопших:"), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      await pumpDepartedSerial(
        tester,
        chapter: 8,
        loader: loader,
        prayersLoader: prayersOf(const PsalterNamedPrayers(signInNeeded: true)),
      );
      expect(find.text(namedPrayersSignInNotice), findsOneWidget);
      // Псалом читается как обычно — плашка молитвы его не останавливает.
      expect(find.textContaining("Псалом 8"), findsWidgets);
    });
  });

  group("границы кафизм и сорокоустный счёт", () {
    test("endsKathisma: концы кафизм видны, середины и Пс 151 — нет", () {
      expect(endsKathisma(8), isTrue);
      expect(endsKathisma(16), isTrue);
      expect(endsKathisma(118), isTrue);
      expect(endsKathisma(150), isTrue);
      expect(endsKathisma(9), isFalse);
      expect(endsKathisma(151), isFalse);
      expect(endsKathisma(0), isFalse);
    });

    test("sorokoustDay: день преставления — первый", () {
      final now = DateTime(2026, 10, 14, 15, 30);
      expect(sorokoustDay("2026-10-14", now), 1);
      expect(sorokoustDay("2026-10-10", now), 5);
      expect(sorokoustDay("2026-09-05", now), 40);
      expect(sorokoustDay("2026-09-04", now), 41);
      expect(sorokoustDay(null, now), isNull);
      expect(sorokoustDay("", now), isNull);
      expect(sorokoustDay("не-дата", now), isNull);
      expect(sorokoustDay("2027-01-01", now), isNull);
    });

    test("sorokoustKathisma: по кругу, 1..20", () {
      expect(sorokoustKathisma(1), 1);
      expect(sorokoustKathisma(20), 20);
      expect(sorokoustKathisma(21), 1);
      expect(sorokoustKathisma(40), 20);
    });
  });
}
