import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/api/bible.dart';

// Ключ кэша главы. Ошибка здесь выглядит не как ошибка: читатель открывает главу
// и видит настоящий текст — просто не в тех изданиях, что выбрал.

void main() {
  group("набор изданий приводится к одному виду", () {
    test("порядок щелчков на набор не влияет", () {
      expect(canonicalEditionCodes(["ro-1688", "cs-eliz"]), ["cs-eliz", "ro-1688"]);
      expect(
        canonicalEditionCodes(["ro-1688", "cs-eliz"]),
        canonicalEditionCodes(["cs-eliz", "ro-1688"]),
      );
    });

    test("повторы и пустые значения отбрасываются", () {
      expect(canonicalEditionCodes(["cs-eliz", "cs-eliz", "", "  "]), ["cs-eliz"]);
    });

    test("пробелы по краям срезаются", () {
      expect(canonicalEditionCodes([" cs-eliz "]), ["cs-eliz"]);
    });
  });

  group("ключ", () {
    test("один и тот же набор в разном порядке даёт один ключ", () {
      // Тело ответа зависит и от набора, и от порядка колонок. Не приведи мы
      // порядок к одному виду, две пары легли бы в один файл разными телами.
      expect(
        bibleChapterCacheKey("matfeya", 1, ["ro-1688", "cs-eliz"]),
        bibleChapterCacheKey("matfeya", 1, ["cs-eliz", "ro-1688"]),
      );
    });

    test("два издания и одно похожее по имени различаются", () {
      // _sanitizeKey в cached_fetch заменяет всё не-буквенно-цифровое на
      // подчёркивание, поэтому "a,b" и одиночное "a-b" дали бы одно имя файла.
      // Разводит их число кодов в ключе.
      final pair = bibleChapterCacheKey("matfeya", 1, ["cs-eliz", "ro-1688"]);
      final single = bibleChapterCacheKey("matfeya", 1, ["cs-eliz-ro-1688"]);

      expect(pair, isNot(single));
      expect(_sanitized(pair), isNot(_sanitized(single)),
          reason: "различаться должны и имена файлов, а не только ключи");
    });

    test("разные книги, главы и наборы дают разные ключи", () {
      final base = bibleChapterCacheKey("matfeya", 1, ["cs-eliz"]);

      expect(base, isNot(bibleChapterCacheKey("marka", 1, ["cs-eliz"])));
      expect(base, isNot(bibleChapterCacheKey("matfeya", 2, ["cs-eliz"])));
      expect(base, isNot(bibleChapterCacheKey("matfeya", 1, ["ro-1688"])));
      expect(base, isNot(bibleChapterCacheKey("matfeya", 1, ["cs-eliz", "ro-1688"])));
    });

    test("пустой набор — свой отдельный ключ, а не чужой", () {
      // Пустой набор сервер понимает как «все публичные издания», и путать его
      // с выбранным одним нельзя.
      expect(
        bibleChapterCacheKey("matfeya", 1, const []),
        isNot(bibleChapterCacheKey("matfeya", 1, ["cs-eliz"])),
      );
    });
  });
}

/// Повторяет приведение ключа к имени файла из cached_fetch.
String _sanitized(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
