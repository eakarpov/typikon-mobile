import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/paged_list.dart';
import 'package:typikon/dto/paged.dart';

/// Запрос сменился, пока прежний был в пути.
///
/// Обычное дело для поиска: человек набирает «вод», запрос ушёл, он дописывает
/// «у». Прежде новая загрузка не начиналась (список считал себя занятым), а
/// прежний ответ отбрасывался, не сняв занятости, — крутилка оставалась навсегда.
void main() {
  Widget host(String query, Future<Paged<String>> Function(int) load) => MaterialApp(
        home: Scaffold(
          body: PagedList<String>(
            resetToken: query,
            load: load,
            itemBuilder: (context, item) => ListTile(title: Text(item)),
            emptyMessage: "пусто",
          ),
        ),
      );

  testWidgets("новая выдача грузится, не дожидаясь прежней", (tester) async {
    final first = Completer<Paged<String>>();
    final second = Completer<Paged<String>>();

    await tester.pumpWidget(host("вод", (_) => first.future));
    await tester.pumpWidget(host("воду", (_) => second.future));

    second.complete(const Paged(items: ["воду живую"], total: 1, limit: 50, offset: 0));
    await tester.pumpAndSettle();
    expect(find.text("воду живую"), findsOneWidget);

    // Опоздавший ответ на прежний запрос в новый список не попадает.
    first.complete(const Paged(items: ["вод многих"], total: 1, limit: 50, offset: 0));
    await tester.pumpAndSettle();
    expect(find.text("вод многих"), findsNothing);
    expect(find.text("воду живую"), findsOneWidget);
  });

  testWidgets("страница короче экрана — следующая догружается сама", (tester) async {
    final offsets = <int>[];
    Future<Paged<String>> load(int offset) async {
      offsets.add(offset);
      return Paged(items: ["строка $offset"], total: 3, limit: 1, offset: offset);
    }

    await tester.pumpWidget(host("q", load));
    await tester.pumpAndSettle();

    expect(offsets, [0, 1, 2]);
    expect(find.text("строка 2"), findsOneWidget);
  });
}
