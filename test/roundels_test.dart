import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/components/dneslov/roundels.dart';
import 'package:typikon/dto/book.dart';

/// Кругляш текста книги. Адрес едет в ответе книги (`roundelUrl`): абсолютный
/// берётся как есть, относительный дополняется до cdn.dneslov.org, а без
/// адреса строка рисует значок — сетевых запросов за образом больше нет.

void main() {
  group("разбор BookText", () {
    test("roundelUrl читается: и полный адрес, и относительный путь", () {
      final absolute = BookText.fromJson(const {
        "name": "Сказание",
        "id": "1",
        "type": "Historic",
        "roundelUrl": "https://cdn.dneslov.org/roundels/57/x.webp",
      });
      final relative = BookText.fromJson(const {
        "name": "Слово",
        "id": "2",
        "type": "Praising",
        "roundelUrl": "/roundels/58/y.webp",
      });

      expect(absolute.roundelUrl, "https://cdn.dneslov.org/roundels/57/x.webp");
      expect(relative.roundelUrl, "/roundels/58/y.webp");
    });

    test("поле опционально: прежние ответы без него разбираются", () {
      final without = BookText.fromJson(const {"name": "Слово", "id": "2", "type": ""});

      expect(without.roundelUrl, isNull);
    });
  });

  group("виджет", () {
    Future<void> pumpRoundel(WidgetTester tester, BookText item) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: Roundels(null, item: item))));

    testWidgets("адрес есть — рисуется образ, запрос к dneslov больше не нужен", (tester) async {
      await pumpRoundel(tester, const BookText(
        name: "Сказание о чуде",
        id: "1",
        dneslovId: "2757",
        textType: "Historic",
        roundelUrl: "/roundels/57/x.webp",
      ));
      await tester.pump();

      // Image.network с дополненным адресом; сеть в тесте молчит, и схлоп
      // обрабатывается errorBuilder — страница не падает.
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, "https://cdn.dneslov.org/roundels/57/x.webp");
      expect(find.text("Сказание о чуде"), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets("адреса нет — значок по роду текста", (tester) async {
      await pumpRoundel(tester, const BookText(
        name: "Поучение о посте",
        id: "2",
        dneslovId: "2757",
        textType: "Teaching",
      ));
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text("Поучение о посте"), findsOneWidget);
    });
  });
}
