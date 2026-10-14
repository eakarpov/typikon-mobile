import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/components/reading_markdown.dart';
import 'package:typikon/dto/saint.dart';
import 'package:typikon/pages/saint_page.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

/// Страница святого: досье и житие грузятся врозь и падают врозь. Загрузка
/// подменяется, чтобы показать обе ветки без сети: житие пришло — рендерится;
/// сервер честно ответил «не связано» — «Повторить» нет, говорит сам сервер.

const _dossier = SaintDossier(name: "Алекса́ндр");

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Future<SaintDossier> Function(String) loadDossier,
    required Future<SaintLife> Function(String) loadLife,
  }) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: SaintPage(
          null,
          id: "aleksandr",
          loadDossier: loadDossier,
          loadLife: loadLife,
        ),
      ),
    ));
  }

  testWidgets("житие пришло — текст на экране", (tester) async {
    await pump(
      tester,
      loadDossier: (_) async => _dossier,
      loadLife: (_) async => SaintLife.fromJson(const {
        "slug": "aleksandr",
        "source": "dneslov",
        "memoes": [
          {"title": "Александр", "happenedAt": null, "description": "Житие пророка."}
        ],
        "links": [],
      }),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReadingMarkdown), findsOneWidget);
    final hasLife = tester.widgetList<RichText>(find.byType(RichText)).any(
        (rich) => rich.text.toPlainText().contains("Житие пророка."));
    expect(hasLife, isTrue);
    // Имя в шапке — из нашей записи, а не из заголовка жития.
    expect(find.text("Алекса́ндр"), findsWidgets);
  });

  testWidgets("404 «житие не связано» — честный отказ без «Повторить»", (tester) async {
    await pump(
      tester,
      loadDossier: (_) async => _dossier,
      loadLife: (_) async => throw const ApiNotFoundException(
          "Житие этой записи пока не связано с каталогом памятей."),
    );
    await tester.pumpAndSettle();

    // Говорит сервер, общий механизм (errorViewFor) кнопки не рисует:
    // повторить нечего — связи у записи нет.
    expect(find.textContaining("не связано"), findsOneWidget);
    expect(find.text("Повторить"), findsNothing);
    // Досье при этом на месте — житие не уносит его с собой.
    expect(find.text("Алекса́ндр"), findsWidgets);
  });
}
