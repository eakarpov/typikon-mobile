import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

/// Текст чтений рисуется через RichText, а он не наследует DefaultTextStyle:
/// при `color == null` движок красит текст белым. Со светлой темой это давало
/// белым по белому — то есть пустую страницу чтения у всех, кто не выбирал
/// цвет вручную. Тест держит фоллбек на цвет темы.
Future<({int min, int max})> _renderLuminance(
  WidgetTester tester,
  Brightness brightness,
) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  final key = GlobalKey();

  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: Container(
            color: brightness == Brightness.light
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF121212),
            width: 200,
            height: 60,
            child: const FusionTextWidgets(
              text: "Слава Отцу и Сыну",
              footnotes: [],
              fontFamily: "OldStandard",
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  ByteData? bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  });

  int min = 255, max = 0;
  for (int i = 0; i < bytes!.lengthInBytes; i += 4) {
    final v = bytes!.getUint8(i);
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return (min: min, max: max);
}

void main() {
  testWidgets("текст чтений виден на светлой теме", (tester) async {
    final result = await _renderLuminance(tester, Brightness.light);
    expect(
      result.min,
      lessThan(200),
      reason: "на белом фоне должны быть тёмные пиксели текста, "
          "иначе текст рисуется белым по белому (min=${result.min})",
    );
  });

  testWidgets("текст чтений виден на тёмной теме", (tester) async {
    final result = await _renderLuminance(tester, Brightness.dark);
    expect(
      result.max,
      greaterThan(100),
      reason: "на тёмном фоне должны быть светлые пиксели текста (max=${result.max})",
    );
  });
}
