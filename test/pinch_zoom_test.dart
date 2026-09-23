import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/components/pinch_zoom.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

// Размер текста щипком — на время экрана, а не настройкой.

void main() {
  Future<Store<AppState>> pump(WidgetTester tester) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: Scaffold(
          body: PinchZoom(
            child: ListView(
              children: const [
                Text("строка песнопения", key: Key("text")),
                FusionTextWidgets(text: "Благословен Бог наш", footnotes: [], fontFamily: "OldStandard"),
                SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    ));
    return store;
  }

  // Масштаб `Text` — из `MediaQuery` под обёрткой. Берём его у самого списка:
  // строка после прокрутки может и выгрузиться.
  double textScale(WidgetTester tester) =>
      MediaQuery.textScalerOf(tester.element(find.byType(ListView))).scale(10) / 10;

  double richScale(WidgetTester tester) =>
      tester.widget<RichText>(find.descendant(
        of: find.byType(FusionTextWidgets),
        matching: find.byType(RichText),
      )).textScaler.scale(10) / 10;

  Future<void> pinch(WidgetTester tester, {required double from, required double to}) async {
    final center = tester.getCenter(find.byType(ListView));
    final a = await tester.startGesture(center - Offset(from / 2, 0), pointer: 1);
    final b = await tester.startGesture(center + Offset(from / 2, 0), pointer: 2);
    await tester.pump();
    for (var step = 1; step <= 5; step++) {
      final d = from + (to - from) * step / 5;
      await a.moveTo(center - Offset(d / 2, 0));
      await b.moveTo(center + Offset(d / 2, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets("разведённые пальцы увеличивают текст обоих видов", (tester) async {
    final store = await pump(tester);
    expect(textScale(tester), 1.0);
    expect(richScale(tester), 1.0);

    await pinch(tester, from: 100, to: 150);

    expect(textScale(tester), closeTo(1.5, 0.05));
    expect(richScale(tester), closeTo(1.5, 0.05),
        reason: "голый RichText масштаба из MediaQuery не берёт — ему отдаётся свой");
    expect(store.state.settings.fontSize, 16, reason: "настройка не меняется");
  });

  testWidgets("кегль не выходит за пределы ползунка настроек", (tester) async {
    await pump(tester);

    await pinch(tester, from: 100, to: 1000);

    // Умолчание 16, предел 40: 2.5 раза.
    expect(textScale(tester), closeTo(40 / 16, 0.01));
  });

  testWidgets("один палец листает, а не масштабирует", (tester) async {
    await pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, greaterThan(0), reason: "страница прокрутилась");
    expect(textScale(tester), 1.0);
  });
}
