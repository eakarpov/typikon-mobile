import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/components/async_view.dart';

/// Обрамление сетевого экрана. Три правила, каждое из которых уже нарушалось на
/// живых страницах, и каждое — своей ошибкой.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets("пока идёт новая загрузка, прежних данных не показываем", (tester) async {
    // Та самая ошибка «День вперёд»: FutureBuilder при смене будущего держит
    // прежние данные, и под новой датой стояли вчерашние чтения.
    Widget viewOf(Future<String> future) => host(AsyncView<String>(
          future: future,
          message: "Не удалось загрузить.",
          builder: (context, data) => Text(data),
        ));

    await tester.pumpWidget(viewOf(Future.value("вчера")));
    await tester.pumpAndSettle();
    expect(find.text("вчера"), findsOneWidget);

    final next = Completer<String>();
    await tester.pumpWidget(viewOf(next.future));
    await tester.pump();

    expect(find.text("вчера"), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    next.complete("сегодня");
    await tester.pumpAndSettle();
    expect(find.text("сегодня"), findsOneWidget);
  });

  testWidgets("отказ показывается словами и с «Повторить»", (tester) async {
    // Прежде здесь стоял Text('${future.error}') — строка, с которой читателю
    // нечего делать, и без единого способа попробовать ещё раз.
    var attempts = 0;
    // Через Completer: у будущего, созданного отказавшим прямо в доводе, на миг
    // нет слушателя, и отказ уходит в обработчик верхнего уровня мимо виджета.
    final failed = Completer<String>();
    await tester.pumpWidget(host(AsyncView<String>(
      future: failed.future,
      message: "Не удалось загрузить книгу.",
      onRetry: () => attempts++,
      builder: (context, data) => Text(data),
    )));
    failed.completeError(Exception("боль"));
    await tester.pumpAndSettle();

    expect(find.byType(ApiErrorView), findsOneWidget);
    expect(find.textContaining("боль"), findsNothing);
    expect(find.text("Не удалось загрузить книгу."), findsOneWidget);

    await tester.tap(find.text("Повторить"));
    expect(attempts, 1);
  });

  testWidgets("без onRetry кнопки нет", (tester) async {
    // Есть отказы, которые повтором не лечатся, и кнопка на них — обман.
    final failed = Completer<String>();
    await tester.pumpWidget(host(AsyncView<String>(
      future: failed.future,
      message: "Не удалось.",
      builder: (context, data) => Text(data),
    )));
    failed.completeError(Exception("нет"));
    await tester.pumpAndSettle();

    expect(find.text("Повторить"), findsNothing);
  });

  testWidgets("пустой ответ — это ответ, а не отказ", (tester) async {
    await tester.pumpWidget(host(AsyncView<List<String>>(
      future: Future.value(const <String>[]),
      message: "Не удалось загрузить.",
      isEmpty: (data) => data.isEmpty,
      emptyMessage: "Ничего не нашлось.",
      builder: (context, data) => Text("строк: ${data.length}"),
    )));
    await tester.pumpAndSettle();

    expect(find.text("Ничего не нашлось."), findsOneWidget);
    expect(find.byType(ApiErrorView), findsNothing);
  });

  testWidgets("потянуть можно и за сообщение об отказе", (tester) async {
    // Короткое состояние само по себе не прокручивается, и без обёртки жест
    // не отзывался бы вовсе — то есть с пустого экрана не было бы выхода.
    var refreshed = 0;
    final failed = Completer<String>();
    await tester.pumpWidget(host(AsyncView<String>(
      future: failed.future,
      message: "Не удалось загрузить.",
      onRefresh: () async => refreshed++,
      builder: (context, data) => Text(data),
    )));
    failed.completeError(Exception("нет сети"));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ApiErrorView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, 1);
  });
}
