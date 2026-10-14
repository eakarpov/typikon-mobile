import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/components/text_search_sheet.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/utils/text_search.dart';

// Поиск по открытому тексту: шторка считает и листает совпадения, страница
// подсвечивает их теми же строителями, что и заметки.

/// Строки спанов с фоном — что подсвечено на экране.
List<String> _highlightedPieces(InlineSpan span) {
  final pieces = <String>[];

  void walk(InlineSpan node) {
    if (node is TextSpan) {
      final text = node.text;
      if (text != null && text.isNotEmpty && node.style?.backgroundColor != null) {
        pieces.add(text);
      }
      for (final child in node.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(span);
  return pieces;
}

void main() {
  group("подсветка совпадений", () {
    Future<List<String>> highlighted(WidgetTester tester, {
      required String text,
      required List<TextRange> matches,
      TextRange? active,
    }) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: FusionTextWidgets(
              text: text,
              footnotes: const [],
              fontFamily: "OldStandard",
              searchMatches: matches,
              activeMatch: active,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      return _highlightedPieces(rich.text);
    }

    testWidgets("совпадение красится фоном", (tester) async {
      final pieces = await highlighted(
        tester,
        text: "Господь благословен",
        matches: const [(0, 7)],
      );

      expect(pieces, ["Господь"]);
    });

    testWidgets("текущее совпадение отличается от прочих", (tester) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: FusionTextWidgets(
              text: "Господь и Господь",
              footnotes: const [],
              fontFamily: "OldStandard",
              searchMatches: const [(0, 7), (10, 17)],
              activeMatch: const (10, 17),
            ),
          ),
        ),
      ));
      await tester.pump();

      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final backgrounds = <Color?>[];
      void walk(InlineSpan node) {
        if (node is TextSpan) {
          if (node.text == "Господь") backgrounds.add(node.style?.backgroundColor);
          for (final child in node.children ?? const <InlineSpan>[]) {
            walk(child);
          }
        }
      }
      walk(rich.text);

      expect(backgrounds.length, 2);
      // Текущее (второе) подсвечено контрастнее — не той подложкой, что прочие.
      expect(backgrounds[0], isNotNull);
      expect(backgrounds[1], isNotNull);
      expect(backgrounds[1], isNot(backgrounds[0]));
    });
  });

  group("шторка поиска", () {
    Future<void> openSheet(WidgetTester tester, {
      required List<String> paragraphs,
      required void Function(Map<int, List<TextRange>>, int) onChanged,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTextSearchSheet(
                context,
                paragraphs: paragraphs,
                onChanged: onChanged,
              ),
              child: const Text("поиск"),
            ),
          ),
        ),
      ));
      await tester.tap(find.text("поиск"));
      await tester.pumpAndSettle();
    }

    testWidgets("введённый запрос уходит на страницу со счётом", (tester) async {
      Map<int, List<TextRange>>? seenMatches;
      var seenCurrent = -1;
      await openSheet(
        tester,
        paragraphs: const ["Господь дал знак. Господь сказал.", "Помяни Господь."],
        onChanged: (matches, current) {
          seenMatches = matches;
          seenCurrent = current;
        },
      );

      await tester.enterText(find.byType(TextField), "господь");
      await tester.pump();

      expect(seenMatches, isNotNull);
      expect(flattenSearchMatches(seenMatches!).length, 3);
      expect(seenCurrent, 0);
      // Счётчик «N из M» — верное M.
      expect(find.text("1 из 3"), findsOneWidget);
    });

    testWidgets("стрелки листают по кругу", (tester) async {
      var seenCurrent = -1;
      await openSheet(
        tester,
        paragraphs: const ["Господь дал знак. Господь сказал."],
        onChanged: (_, current) => seenCurrent = current,
      );
      await tester.enterText(find.byType(TextField), "господь");
      await tester.pump();

      await tester.tap(find.byTooltip("Следующее"));
      await tester.pump();
      expect(seenCurrent, 1);
      expect(find.text("2 из 2"), findsOneWidget);

      // С последнего — на первое.
      await tester.tap(find.byTooltip("Следующее"));
      await tester.pump();
      expect(seenCurrent, 0);
      expect(find.text("1 из 2"), findsOneWidget);
    });

    testWidgets("короткий запрос — нет совпадений", (tester) async {
      await openSheet(
        tester,
        paragraphs: const ["Господь благословен"],
        onChanged: (matches, current) {
          expect(matches, isEmpty);
          expect(current, 0);
        },
      );
      await tester.enterText(find.byType(TextField), "г");
      await tester.pump();

      expect(find.text("Нет совпадений"), findsOneWidget);
    });
  });
}
