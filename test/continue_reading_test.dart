import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/components/continue_reading.dart';
import 'package:typikon/store/reading_progress.dart';

// Секция «Продолжить чтение» на главной: имя, полоса прогресса, тап в текст.
// Записи без имени (сохранённые до фичи) не показываются.

void main() {
  SavedReading named(String id, String name, double fraction) =>
      SavedReading(id, ReadingProgress(fraction, DateTime(2026, 1, 1), name: name));

  SavedReading unnamed(String id, double fraction) =>
      SavedReading(id, ReadingProgress(fraction, DateTime(2026, 1, 1)));

  Future<void> pump(WidgetTester tester, List<SavedReading> entries, {
    required void Function(String?) onOpened,
  }) {
    return tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == "/reading") {
          onOpened(settings.arguments as String?);
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Text("открыто")));
        }
        return null;
      },
      home: Scaffold(body: ContinueReading(entries: entries)),
    ));
  }

  testWidgets("показывает имя и прогресс", (tester) async {
    await pump(tester, [
      named("t1", "Житие преподобного", 0.5),
      named("t2", "Слово на индикт", 0.25),
    ], onOpened: (_) {});

    expect(find.text("Продолжить чтение"), findsOneWidget);
    expect(find.text("Житие преподобного"), findsOneWidget);
    expect(find.text("Слово на индикт"), findsOneWidget);

    final bars = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bars.map((b) => b.value), [0.5, 0.25]);
  });

  testWidgets("тап ведёт в текст с id записи", (tester) async {
    String? opened;
    await pump(tester, [named("t1", "Житие преподобного", 0.5)],
        onOpened: (id) => opened = id);

    await tester.tap(find.text("Житие преподобного"));
    await tester.pumpAndSettle();

    expect(opened, "t1");
    expect(find.text("открыто"), findsOneWidget);
  });

  testWidgets("безымянные записи не показываются, и без записей секции нет",
      (tester) async {
    await pump(tester, [unnamed("t1", 0.5)], onOpened: (_) {});

    expect(find.text("Продолжить чтение"), findsNothing);

    await pump(tester, const [], onOpened: (_) {});
    expect(find.text("Продолжить чтение"), findsNothing);
  });
}
