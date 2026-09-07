import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/day_memories.dart';
import 'package:typikon/dto/calendar.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

/// "Святые дня" на главной рисуются через RichText, а он ничего не наследует:
/// цвет там был прибит к Colors.black, и на тёмной теме блок пропадал.
const _memories = DayMemories(
  defaultMemory: DayMemory(
    id: "1",
    name: "Обрезание Господне",
    sign: "SIX_STICHERA",
    signConditional: false,
    order: 0,
  ),
  secondary: [
    DayMemory(id: "2", name: "Василий Великий", sign: "GREAT_VIGIL", signConditional: false, order: 1),
  ],
);

/// Стиль строки с именем святого — и цвет её глифа знака.
Future<({Color? text, Color? glyph})> _rowColors(WidgetTester tester, Brightness brightness) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const Scaffold(body: DayMemoriesView(memories: _memories)),
    ),
  ));
  await tester.pumpAndSettle();

  final row = tester.widgetList<RichText>(find.byType(RichText)).firstWhere(
        (w) => w.text.toPlainText().contains("Обрезание Господне"),
      );
  final span = row.text as TextSpan;
  final glyphSpan = span.children!.first as TextSpan;
  return (text: span.style?.color, glyph: glyphSpan.style?.color);
}

void main() {
  testWidgets("имя святого берёт цвет темы, а не чёрный", (tester) async {
    final light = await _rowColors(tester, Brightness.light);
    final dark = await _rowColors(tester, Brightness.dark);

    expect(light.text, isNotNull);
    expect(dark.text, isNotNull);
    expect(dark.text, isNot(light.text), reason: "на тёмной теме цвет обязан отличаться от светлой");
    expect(
      dark.text!.computeLuminance(),
      greaterThan(0.5),
      reason: "на тёмном фоне имя святого должно быть светлым, было ${dark.text}",
    );
    expect(light.text!.computeLuminance(), lessThan(0.5));
  });

  testWidgets("чёрный глиф шестеричного знака следует за цветом текста", (tester) async {
    final dark = await _rowColors(tester, Brightness.dark);
    expect(dark.glyph, dark.text);
  });

  testWidgets("красный глиф остаётся красным на обеих темах", (tester) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: DayMemoriesView(memories: _memories)),
      ),
    ));
    await tester.pumpAndSettle();

    final row = tester.widgetList<RichText>(find.byType(RichText)).firstWhere(
          (w) => w.text.toPlainText().contains("Василий Великий"),
        );
    final glyph = (row.text as TextSpan).children!.first as TextSpan;
    expect(glyph.style?.color, Colors.red);
  });
}
