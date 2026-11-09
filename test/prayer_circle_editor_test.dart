import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/domain/prayer_circle.dart';
import 'package:typikon/pages/prayer_circle_editor.dart';

void main() {
  testWidgets(
    'editor creates a separate personal variant and keeps the original',
    (tester) async {
      final c = initialCircleConfig();
      await tester.pumpWidget(
        MaterialApp(
          home: PrayerCircleEditor(
            config: c,
            catalog: {'templates': [], 'options': {}},
          ),
        ),
      );
      await tester.tap(find.text('Пустой вариант'));
      await tester.pumpAndSettle();
      expect(find.text('Новое правило'), findsWidgets);
      expect(circleList(c['variants']).length, 1);
      expect(circleList(c['variants']).first['title'], 'Обычное правило');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('narrow phone layout handles a long variant title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = initialCircleConfig();
    (c['variants'] as List).first['title'] =
        'Моё обычное молитвенное правило и ежедневные чтения';
    await tester.pumpWidget(
      MaterialApp(
        home: PrayerCircleEditor(
          config: c,
          catalog: {'templates': [], 'options': {}},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
