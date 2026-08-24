import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/utils/fb2.dart';

void main() {
  final now = DateTime(2026, 8, 24);

  String build({String name = "Слово", String? author, String content = "Текст"}) {
    return buildFb2(id: "abc123", name: name, author: author, content: content, now: now);
  }

  group("экранирование", () {
    test("амперсанд и угловые скобки не ломают xml", () {
      final fb2 = build(name: "Пётр & Павел", content: "а < б и в > г, а также &");

      expect(fb2, contains("<book-title>Пётр &amp; Павел</book-title>"));
      expect(fb2, contains("а &lt; б и в &gt; г, а также &amp;"));
      // Никаких сырых "&", кроме уже экранированных сущностей.
      expect(RegExp(r"&(?!amp;|lt;|gt;)").hasMatch(fb2), isFalse);
    });

    test("амперсанд не экранируется дважды", () {
      expect(escapeXml("a & b"), "a &amp; b");
      expect(escapeXml("<&>"), "&lt;&amp;&gt;");
    });
  });

  group("содержимое", () {
    test("абзацы разъезжаются по отдельным <p>", () {
      final fb2 = build(content: "Первый абзац\n\nВторой абзац\n\nТретий");

      expect(fb2, contains("<p>Первый абзац</p>"));
      expect(fb2, contains("<p>Второй абзац</p>"));
      expect(fb2, contains("<p>Третий</p>"));
    });

    test("внутренняя разметка в файл не уезжает", () {
      final fb2 = build(content: "Слава {k|Отцу} и Сыну{12}");

      expect(fb2, contains("Слава Отцу и Сыну"));
      expect(fb2, isNot(contains("{k|")));
      expect(fb2, isNot(contains("{12}")));
    });

    test("пустые куски не превращаются в пустые абзацы", () {
      final fb2 = build(content: "Один\n\n\n\nДва");

      expect(fb2, isNot(contains("<p></p>")));
      expect(splitParagraphs("Один\n\n\n\nДва"), ["Один", "Два"]);
    });
  });

  group("метаданные", () {
    test("автор берётся из текста, дата — текущая, язык русский", () {
      final fb2 = build(author: "Иоанн Златоуст");

      expect(fb2, contains("<nickname>Иоанн Златоуст</nickname>"));
      expect(fb2, contains('<date value="2026-08-24">24.08.2026</date>'));
      expect(fb2, contains("<lang>ru</lang>"));
      expect(fb2, contains("<id>abc123</id>"));
    });

    test("без автора подставляется заглушка, а не 'No author'", () {
      final fb2 = build(author: "   ");

      expect(fb2, contains("<nickname>Автор не указан</nickname>"));
      expect(fb2, isNot(contains("No author")));
    });
  });

  group("имя файла", () {
    test("берётся из названия текста и чистится от запрещённых символов", () {
      expect(fb2FileName("Слово / на  Рождество"), "Слово на Рождество");
    });

    test("пустое название не даёт пустое имя файла", () {
      expect(fb2FileName("   "), "Из уставных чтений");
    });

    test("очень длинное название подрезается", () {
      expect(fb2FileName("а" * 200).length, lessThanOrEqualTo(80));
    });
  });
}
