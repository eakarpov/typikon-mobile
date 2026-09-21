import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/utils/text.dart';

/// Номера статий и сносок приходят с сервера, а считаются здесь — и сойтись не
/// обязаны. Выход за край был исключением в `build` и пустой страницей.
void main() {
  const kathisma = "зачин[Статия 1]первая[Статия 2]вторая";

  group("статия", () {
    test("берётся по номеру с единицы", () {
      expect(statiaContent(kathisma, 2), "первая");
    });

    test("без номера — первая часть", () {
      expect(statiaContent(kathisma, null), "зачин");
    });

    test("номер за краем — текст целиком, а не исключение", () {
      expect(statiaContent(kathisma, 9), kathisma);
      expect(statiaContent(kathisma, 0), kathisma);
    });

    test("текст без разметки статий отдаётся целиком", () {
      expect(statiaContent("просто текст", 3), "просто текст");
    });
  });

  group("сноска", () {
    const footnotes = ["нулевая", "первая"];

    test("находится по номеру", () {
      expect(footnoteAt(footnotes, "1"), "первая");
    });

    test("номер без сноски и мусор в метке — null", () {
      expect(footnoteAt(footnotes, "7"), isNull);
      expect(footnoteAt(footnotes, "а"), isNull);
      expect(footnoteAt(footnotes, null), isNull);
    });
  });
}
