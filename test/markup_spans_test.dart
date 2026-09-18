import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/components/places.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

// Разметка в тексте чтения: киноварь, места, святые.
//
// Ошибка здесь не видна ни в логе, ни в тестах на данных — она возникает при
// рисовании и выглядит не как поломка, а как испорченный текст: подпись ссылки
// тянется через полабзаца, а часть слов пропадает. Читатель решит, что так
// набрано в книге.
//
// Замерено по дампу корпуса (7972 текста): меток киновари 871, и в 23 абзацах
// их по две — ровно те абзацы, что ломало жадное выражение.

/// Кусок разобранного текста: что написано, красным ли и нажимается ли.
class Piece {
  final String text;
  final Color? color;
  final bool tappable;

  const Piece(this.text, this.color, this.tappable);

  @override
  String toString() => "«$text»${tappable ? " (ссылка)" : ""}";
}

List<Piece> _flatten(InlineSpan span) {
  final pieces = <Piece>[];

  void walk(InlineSpan node) {
    if (node is TextSpan) {
      final text = node.text;
      if (text != null && text.isNotEmpty) {
        pieces.add(Piece(text, node.style?.color, node.recognizer != null));
      }
      for (final child in node.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(span);
  return pieces;
}

/// Строка целиком, как её увидит читатель.
String _plain(List<Piece> pieces) => pieces.map((p) => p.text).join();

/// Разбирает абзац теми же строителями, что и страница чтения.
Future<List<Piece>> pieces(WidgetTester tester, String text) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());
  final spans = <InlineSpan>[];

  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          spans
            ..clear()
            ..addAll(buildPlaces(text, 16.0, context, "Roboto"));
          return RichText(text: TextSpan(children: spans));
        }),
      ),
    ),
  ));
  await tester.pump();

  expect(tester.takeException(), isNull);
  return _flatten(TextSpan(children: spans));
}

/// Киноварь разбирается не строителем, а самим виджетом.
Future<List<Piece>> kinovar(WidgetTester tester, String text) async {
  final store = Store<AppState>(appReducer, initialState: AppState.init());

  await tester.pumpWidget(StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: Scaffold(
        body: FusionTextWidgets(
          text: text,
          footnotes: const [],
          fontFamily: "Roboto",
        ),
      ),
    ),
  ));
  await tester.pump();

  expect(tester.takeException(), isNull);
  final rich = tester.widget<RichText>(find.byType(RichText).first);
  return _flatten(rich.text);
}

void main() {
  group("места", () {
    testWidgets("два места в одном абзаце остаются двумя ссылками", (tester) async {
      // Та самая поломка: жадное выражение сливало пару меток в одну ссылку с
      // подписью «Афины} и {pl», а второе место пропадало вместе с союзом.
      final parsed = await pieces(
        tester,
        "Был в {pl|a1|Афинах} и в {pl|b2|Риме} проповедал",
      );

      final links = parsed.where((p) => p.tappable).toList();
      expect(links.map((p) => p.text), ["Афинах", "Риме"]);
      expect(_plain(parsed), "Был в Афинах и в Риме проповедал");
    });

    testWidgets("метка без подписи показывает свой ключ, а не роняет абзац", (tester) async {
      // Прежде здесь был RangeError: подписи нет, а её брали по индексу.
      final parsed = await pieces(tester, "у {pl|ierusalim} ныне");

      expect(parsed.singleWhere((p) => p.tappable).text, "ierusalim");
      expect(_plain(parsed), "у ierusalim ныне");
    });

    testWidgets("метка в начале и в конце абзаца", (tester) async {
      final parsed = await pieces(tester, "{pl|a1|Афины} и {pl|b2|Рим}");

      expect(parsed.where((p) => p.tappable).map((p) => p.text), ["Афины", "Рим"]);
      expect(_plain(parsed), "Афины и Рим");
      expect(parsed.any((p) => p.text.trim().isEmpty && !p.tappable), isFalse,
          reason: "пустых кусков между метками быть не должно");
    });

    testWidgets("закрывающая скобка дальше по строке метку не удлиняет", (tester) async {
      final parsed = await pieces(tester, "{pl|a1|Афины} (как сказано выше}");

      expect(parsed.singleWhere((p) => p.tappable).text, "Афины");
      expect(_plain(parsed), "Афины (как сказано выше}");
    });
  });

  group("святые рядом с местами", () {
    testWidgets("обе разметки в одном абзаце разбираются", (tester) async {
      // Строители идут цепочкой: места разбирают текст первыми и отдают
      // остаток святым. Ошибка в любом звене съедает метки следующего.
      final parsed = await pieces(
        tester,
        "{st|7307|Гавриил} явился в {pl|a1|Назарете}",
      );

      expect(parsed.where((p) => p.tappable).map((p) => p.text),
          ["Гавриил", "Назарете"]);
      expect(_plain(parsed), "Гавриил явился в Назарете");
    });
  });

  group("текст без разметки", () {
    testWidgets("остаётся собой", (tester) async {
      final parsed = await pieces(tester, "Слава Отцу и Сыну и Святому Духу");

      expect(parsed.any((p) => p.tappable), isFalse);
      expect(_plain(parsed), "Слава Отцу и Сыну и Святому Духу");
    });
  });

  group("киноварь", () {
    testWidgets("две метки в абзаце — две красные строки, текст между ними цел",
        (tester) async {
      // Образец из корпуса: служба Косме, 8 марта. Жадное выражение делало из
      // двух указаний одно, а строку между ними стирало.
      final parsed = await kinovar(
        tester,
        "{k|Стихиры Богородицы:} Ныне наста {k|Аще аллилуиа:}",
      );

      final red = parsed.where((p) => p.color == Colors.red).map((p) => p.text);
      expect(red, ["Стихиры Богородицы:", "Аще аллилуиа:"]);
      expect(_plain(parsed), "Стихиры Богородицы: Ныне наста Аще аллилуиа:");
    });

    testWidgets("незакрытая метка показывается собой, а не глотает абзац",
        (tester) async {
      // Таких в корпусе три. Прежде вторая метка закрывала первую, и всё
      // между ними уходило в киноварь вместе с самой разметкой.
      final parsed = await kinovar(tester, "{k|Стих: Внегда воззвати\n\nВо вторник");

      expect(parsed.any((p) => p.color == Colors.red), isFalse);
      expect(_plain(parsed), "{k|Стих: Внегда воззвати\n\nВо вторник");
    });
  });
}
