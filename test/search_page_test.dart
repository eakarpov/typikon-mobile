import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:typikon/dto/search.dart';
import 'package:typikon/pages/search_page.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

/// Поиск по чтениям шлёт один запрос на слово, а не по запросу на букву.
///
/// Запрос создавался в `build`, а экран перерисовывается на каждой букве — пауза
/// перед отправкой ничего не сдерживала, и лимит сервера выбирался набором
/// одного длинного слова.
void main() {
  testWidgets("набор слова — один запрос", (tester) async {
    final queries = <String>[];
    Future<List<SearchBookText>> search(String query) async {
      queries.add(query);
      return const <SearchBookText>[];
    }

    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: Builder(builder: (context) => SearchPage(context, searchTexts: search)),
      ),
    ));

    for (final typed in ["в", "во", "вод", "вода"]) {
      await tester.enterText(find.byType(TextField), typed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(queries, ["вода"]);

    // Перерисовка без смены запроса (пробел в конце) сеть не трогает.
    await tester.enterText(find.byType(TextField), "вода ");
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(queries, ["вода"]);
  });
}
