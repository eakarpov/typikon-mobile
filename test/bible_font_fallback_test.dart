import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/bible_edition_picker.dart';
import 'package:typikon/dto/bible.dart';

void main() {
  testWidgets('китайское и грузинское издания можно выбрать', (tester) async {
    List<String>? result;
    final editions = [
      for (final pair in [('zh', '中文'), ('ka', 'ქართული')])
        BibleEdition(
          code: pair.$1,
          title: pair.$2,
          shortTitle: pair.$2,
          language: pair.$1,
          languageCode: pair.$1,
          versification: 'other',
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showEditionPicker(
                  context,
                  editions: editions,
                  selected: ['zh'],
                );
              },
              child: const Text('Выбрать'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    expect(find.textContaining('нет шрифта'), findsNothing);
    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(tile.onChanged, isNotNull);
    }
    await tester.tap(find.text('ქართული'));
    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();
    expect(result, ['zh', 'ka']);
  });
}
