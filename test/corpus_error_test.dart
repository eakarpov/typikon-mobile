import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/apiMapper/singing.dart';
import 'package:typikon/components/paged_list.dart';

// Отказ певческого корпуса. Он не поломка приложения и не вина читателя: корпус
// выкладывается на сервер отдельно от кода, и бывает заперт на время пересборки.
// Кнопка «Повторить» здесь была бы обещанием, которого повтор не выполнит.

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets("невыложенный корпус не предлагает повторить", (tester) async {
    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => searchErrorView(
          context,
          const CorpusUnavailableException("Певческий корпус сейчас недоступен."),
          "Не удалось открыть каноны.",
          () {},
        ),
      ),
    ));

    expect(find.text("Певческий корпус сейчас недоступен."), findsOneWidget);
    expect(find.textContaining("Повторять бесполезно"), findsOneWidget);
    expect(find.text("Повторить"), findsNothing);
    // Про поломку приложения сказано прямо: иначе читатель понесёт нам отзыв о
    // сломавшемся разделе.
    expect(find.textContaining("не поломка приложения"), findsOneWidget);
  });

  testWidgets("прочий отказ повторить предлагает", (tester) async {
    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => searchErrorView(
          context,
          Exception("сеть"),
          "Не удалось открыть каноны.",
          () {},
        ),
      ),
    ));

    expect(find.text("Повторить"), findsOneWidget);
  });
}
