import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/components/selection_menu.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

/// Текст чтения выделяется.
///
/// Он рисуется голым RichText, а тот, в отличие от Text, в SelectionArea себя
/// не записывает: долгое нажатие не давало ничего, и до «Добавить заметку»,
/// «Сообщить об ошибке» и простого «Копировать» было не добраться. Не вошедшему
/// SelectionArea не доставалось вовсе.
void main() {
  Future<void> pumpReading(WidgetTester tester, {required bool signedIn}) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: Scaffold(
          body: SelectionMenu(
            enabled: signedIn,
            textId: "t1",
            containers: const [],
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

  Future<void> pumpReadingWithShare(WidgetTester tester, {bool withShare = true}) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: Scaffold(
          body: SelectionMenu(
            enabled: false,
            textId: "t1",
            containers: const [],
            shareLinkFor: withShare ? (phrase) => "https://www.typikon.info/reading/t1" : null,
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

  for (final signedIn in [true, false]) {
    testWidgets("долгое нажатие выделяет слово (вошёл: $signedIn)", (tester) async {
      await pumpReading(tester, signedIn: signedIn);

      await tester.longPress(find.byType(RichText).first);
      await tester.pumpAndSettle();

      // Меню над выделением появляется, только если что-то выделилось.
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    });
  }

  group("поделиться", () {
    testWidgets("пункт есть, когда задан shareLinkFor", (tester) async {
      await pumpReadingWithShare(tester);

      await tester.longPress(find.byType(RichText).first);
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      // Сам SharePlus не вызываем: в тесте нет канала — проверяем только, что
      // пункт дошёл до тулбара.
      expect(find.text("Поделиться"), findsOneWidget);
    });

    testWidgets("без shareLinkFor пункта нет", (tester) async {
      await pumpReadingWithShare(tester, withShare: false);

      await tester.longPress(find.byType(RichText).first);
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(find.text("Поделиться"), findsNothing);
    });
  });
}
