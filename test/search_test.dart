import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/api/search.dart';
import 'package:typikon/apiMapper/search.dart';
import 'package:typikon/dto/search.dart';

void main() {
  group("разбор ответа поиска", () {
    test("берёт фрагмент, описание и автора", () {
      final item = SearchBookText.fromJson({
        "id": "63f517193f71d33cda1d9f4e",
        "name": "Пасха. Слово 8",
        "snippet": "…и ждет тре́тияго дне…",
        "description": "Слово на святу́ю Па́сху",
        "author": "Григорий Богослов",
      });

      expect(item.id, "63f517193f71d33cda1d9f4e");
      expect(item.name, "Пасха. Слово 8");
      expect(item.snippet, "…и ждет тре́тияго дне…");
      expect(item.author, "Григорий Богослов");
    });

    test("id берётся из _id, если поля id нет", () {
      final item = SearchBookText.fromJson({"_id": "abc", "name": "Текст"});

      expect(item.id, "abc");
    });

    test("пустые строки не выдаются за значения", () {
      // Автор в базе часто пустая строка, а не отсутствующее поле — иначе под
      // названием печаталась бы пустая строчка.
      final item = SearchBookText.fromJson({
        "id": "1", "name": "Текст", "author": "  ", "snippet": "", "description": "",
      });

      expect(item.author, isNull);
      expect(item.snippet, isNull);
      expect(item.excerpt, isNull);
    });
  });

  group("что показываем под названием", () {
    SearchBookText make({String? snippet, String? description}) => SearchBookText(
          id: "1", name: "Текст", snippet: snippet, description: description,
        );

    test("фрагмент важнее описания", () {
      expect(make(snippet: "фрагмент", description: "описание").excerpt, "фрагмент");
    });

    test("без фрагмента показываем описание", () {
      // Совпало название — сервер фрагмент не присылает (snippet: null).
      expect(make(description: "описание").excerpt, "описание");
    });

    test("нет ни того, ни другого — ничего", () {
      expect(make().excerpt, isNull);
    });
  });

  group("короткий запрос", () {
    test("отсекается до похода в сеть", () {
      expect(
        () => getSearchResult("Па"),
        throwsA(isA<SearchQueryTooShortException>()),
      );
    });

    test("пустой запрос — просто пустая выдача, без ошибки", () async {
      expect(await getSearchResult(""), isEmpty);
      expect(await getSearchResult(null), isEmpty);
    });

    test("порог совпадает с бекендом", () {
      expect(minSearchQueryLength, 3);
    });
  });
}
