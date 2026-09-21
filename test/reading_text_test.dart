import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/reading_markdown.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/utils/reading_style.dart';

/// Настройки чтения должны доходить до всякого пути отрисовки.
///
/// Их шесть, и половина мест знала про половину: калькулятор не брал ни цвета,
/// ни выключки, страница дня прибивала выключку к justify и забывала интервал,
/// а разметка не знала ни одной. Настройка, которую половина экранов не
/// соблюдает, хуже отсутствующей: человек её выставил и считает, что она
/// действует.
void main() {
  Future<Store<AppState>> pump(WidgetTester tester, Widget child) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    store.dispatch(ChangeFontSizeAction(31));
    store.dispatch(ChangeLineHeightAction(2.1));
    store.dispatch(ChangeReadingAlignAction("left"));
    store.dispatch(ChangeFontColorAction(const Color(0xFF00FF00)));

    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(home: Scaffold(body: child)),
    ));
    return store;
  }

  testWidgets("проза чтения берёт все шесть настроек", (tester) async {
    await pump(tester, const ReadingText("Благословен Бог наш"));

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.fontSize, 31);
    expect(text.style?.height, 2.1);
    expect(text.style?.color, const Color(0xFF00FF00));
    expect(text.style?.fontFamily, "OldStandard");
    // Выключка — из настроек, а не прибитая justify, как было на странице дня.
    expect(text.textAlign, TextAlign.left);
  });

  testWidgets("церковнославянский идёт своим шрифтом", (tester) async {
    // OldStandard не несёт ни надстрочных знаков, ни буквенных цифр.
    await pump(tester, const ReadingText("Бг҃ъ", churchSlavonic: true));

    expect(tester.widget<Text>(find.byType(Text)).style?.fontFamily, "Monomakh");
  });

  testWidgets("разметка набирается теми же настройками", (tester) async {
    await pump(tester, const ReadingMarkdown("Слава Отцу", scrollable: false));
    await tester.pumpAndSettle();

    // Стиль абзаца лежит на внутреннем пролёте: внешний несёт умолчание темы.
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final paragraph = (rich.text as TextSpan).children!.first as TextSpan;
    expect(paragraph.text, "Слава Отцу");
    expect(paragraph.style?.fontSize, 31);
    expect(paragraph.style?.height, 2.1);
    expect(paragraph.style?.fontFamily, "OldStandard");
  });

  testWidgets("встроенная разметка не заводит своей прокрутки", (tester) async {
    // Прежде текст с newUi жил в SizedBox(height: 350) со своей прокруткой
    // посреди страницы, которая прокручивается сама.
    await pump(tester, const ReadingMarkdown("Слава Отцу", scrollable: false));
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsNothing);
  });
}
