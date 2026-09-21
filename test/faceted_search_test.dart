import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/faceted_search.dart';

/// Поле поиска с паузой. Пауза была переписана в семи местах и успела
/// разойтись: где 400 мс, где 500, где-то крестик появлялся с опозданием на всю
/// паузу, а где-то setState звался из таймера на снятом с дерева экране.
void main() {
  Widget host(ValueChanged<String> onQuery) => MaterialApp(
        home: Scaffold(
          body: SearchQueryField(hintText: "Слово", onQuery: onQuery),
        ),
      );

  testWidgets("набор слова — один запрос, после паузы", (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(host(queries.add));

    for (final typed in ["в", "во", "вод", "вода"]) {
      await tester.enterText(find.byType(TextField), typed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(queries, isEmpty, reason: "пока набирают — не ищем");

    await tester.pump(const Duration(milliseconds: 400));
    expect(queries, ["вода"]);
  });

  testWidgets("тот же запрос второй раз не уходит", (tester) async {
    // Пауза срабатывает и на пробел в конце, а лишний запрос — лишняя выдача.
    final queries = <String>[];
    await tester.pumpWidget(host(queries.add));

    await tester.enterText(find.byType(TextField), "вода");
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), "вода ");
    await tester.pump(const Duration(milliseconds: 500));

    expect(queries, ["вода"]);
  });

  testWidgets("крестик появляется сразу, а не через паузу", (tester) async {
    // В канонах его не было видно до конца паузы: setState при наборе не звали.
    await tester.pumpWidget(host((_) {}));
    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), "в");
    await tester.pump();

    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets("очистка сбрасывает запрос сразу", (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(host(queries.add));

    await tester.enterText(find.byType(TextField), "вода");
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(queries, ["вода", ""]);
  });

  testWidgets("экран сняли до конца паузы — запроса нет", (tester) async {
    // Словарь и именины звали setState из таймера без проверки.
    final queries = <String>[];
    await tester.pumpWidget(host(queries.add));
    await tester.enterText(find.byType(TextField), "вода");

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(queries, isEmpty);
  });

  testWidgets("полоса отборов без отборов не занимает места", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FacetBar(chips: [])),
    ));

    expect(tester.getSize(find.byType(FacetBar)).height, 0);
  });
}
