import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/snippet_text.dart';
import 'package:typikon/dto/chant.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

/// Подсветка найденного — единственное, ради чего фрагмент приходит кусками, а
/// не строкой. Потеряй мы флаг — получился бы поиск, который ничего не находит
/// на вид: текст показан, а где в нём совпадение, читателю не видно.

const List<SnippetPart> parts = [
  SnippetPart(text: "Услыши мя, Господи, ", hit: false),
  SnippetPart(text: "воззвах", hit: true),
  SnippetPart(text: " к Тебе", hit: false),
];

Future<RichText> pump(WidgetTester tester, {Color? fontColor}) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  if (fontColor != null) store.dispatch(ChangeFontColorAction(fontColor));

  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: const Scaffold(
        body: SnippetText(parts: parts, fontSize: 16.0),
      ),
    ),
  ));
  await tester.pump();

  return tester.widget<RichText>(find.byType(RichText));
}

List<TextSpan> spansOf(RichText rich) =>
    ((rich.text as TextSpan).children ?? []).cast<TextSpan>();

void main() {
  testWidgets("весь текст доходит до экрана, ни один кусок не потерян", (tester) async {
    final rich = await pump(tester);

    expect(spansOf(rich).map((s) => s.text).join(), "Услыши мя, Господи, воззвах к Тебе");
  });

  testWidgets("подсвечен ровно найденный кусок", (tester) async {
    final spans = spansOf(await pump(tester));

    expect(spans.length, 3);
    expect(spans[0].style?.backgroundColor, isNull);
    expect(spans[1].style?.backgroundColor, isNotNull);
    expect(spans[2].style?.backgroundColor, isNull);
  });

  testWidgets("найденное выделено ещё и начертанием", (tester) async {
    // Одной подложки мало: при выбранном пользователем цвете чтения она может
    // оказаться малозаметной.
    final spans = spansOf(await pump(tester));

    expect(spans[1].style?.fontWeight, FontWeight.bold);
    expect(spans[0].style?.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets("подложка выбирается по светлоте текста, а не наугад", (tester) async {
    // Белым по бледно-жёлтому не прочесть. Тот же случай, что с подсветкой
    // заметок, и решается так же — по светлоте самого текста, потому что цвет
    // чтения читатель мог выбрать сам, вопреки теме.
    final onDarkText =
        spansOf(await pump(tester, fontColor: const Color(0xFF000000))).elementAt(1);
    final onLightText =
        spansOf(await pump(tester, fontColor: const Color(0xFFFFFFFF))).elementAt(1);

    expect(onDarkText.style?.backgroundColor, isNotNull);
    expect(onLightText.style?.backgroundColor, isNotNull);
    expect(onDarkText.style?.backgroundColor,
        isNot(onLightText.style?.backgroundColor),
        reason: 'светлому и тёмному тексту нужна разная подложка');
  });

  testWidgets("пустой фрагмент не роняет отрисовку", (tester) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());

    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: const MaterialApp(
        home: Scaffold(body: SnippetText(parts: [], fontSize: 16.0)),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
