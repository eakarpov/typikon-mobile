import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/pages/prayer_circle_page.dart';

void main() {
  testWidgets(
    'ready Horologion and other rules are selectable before creating a personal variant',
    (tester) async {
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrayerCircleRuleDropdown(
              value: 'ordinary',
              variants: [
                {'id': 'ordinary', 'title': 'Обычное правило'},
              ],
              catalog: {
                'templates': [
                  {
                    'id': 'horologion',
                    'key': 'horologion',
                    'title': 'Правило по Часослову',
                    'status': 'verified',
                  },
                  {
                    'id': 'serafim',
                    'key': 'serafimovo',
                    'title': 'Краткое Серафимово правило',
                    'status': 'verified',
                  },
                  {
                    'id': 'old',
                    'key': 'old',
                    'title': 'Канонник 1636',
                    'status': 'needs_collation',
                  },
                ],
              },
              onChanged: (v) => chosen = v,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Правило по Часослову'), findsOneWidget);
      expect(find.text('Краткое Серафимово правило'), findsOneWidget);
      expect(find.text('Канонник 1636'), findsNothing);
      await tester.tap(find.text('Правило по Часослову'));
      await tester.pumpAndSettle();
      expect(chosen, 'template:horologion');
      expect(tester.takeException(), isNull);
    },
  );
}
