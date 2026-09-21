import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/utils/place_labels.dart';

// Подписи мест. Сервер шлёт коды, русские слова знает приложение — и всякий
// незнакомый код должен показаться как есть, а не спрятаться: заведут в корпусе
// новый род места, и молчание выглядело бы как потеря записи.

void main() {
  group("роды и состояния", () {
    test("известное переводится", () {
      expect(placeKindLabel("settlement"), "город");
      expect(placeStatusLabel("ruins"), "в развалинах");
    });

    test("незнакомое показывается собой", () {
      expect(placeKindLabel("оазис"), "оазис");
      expect(placeStatusLabel("затоплено"), "затоплено");
    });

    test("пустое остаётся пустым, а не становится словом", () {
      expect(placeKindLabel(null), "");
      expect(placeStatusLabel(""), "");
    });
  });

  group("связи", () {
    test("одна запись читается по-разному с разных концов", () {
      // «Преемник» и «предшественник» — та же самая связь, и перепутать концы
      // значило бы перевернуть историю места.
      expect(placeRelationLabel("succeeds", "out"), "Преемник");
      expect(placeRelationLabel("succeeds", "in"), "Предшественник");
    });

    test("отождествление читается одинаково с обеих сторон", () {
      expect(placeRelationLabel("identified_with", "out"),
          placeRelationLabel("identified_with", "in"));
    });

    test("незнакомая связь показывается своим кодом", () {
      expect(placeRelationLabel("merged_with", "out"), "merged_with");
    });
  });

  group("годы", () {
    test("до Рождества Христова — отрицательные", () {
      expect(placeYearLabel(-330), "330 до Р. Х.");
      expect(placeYearLabel(1453), "1453");
    });

    test("промежуток называется обоими концами", () {
      expect(placeSpanLabel(-516, 70), "516 до Р. Х. — 70");
    });

    test("открытый промежуток не выдумывает второго конца", () {
      expect(placeSpanLabel(638, null), "с 638");
      expect(placeSpanLabel(null, 1453), "до 1453");
      expect(placeSpanLabel(null, null), "");
    });
  });

  group("внешние источники", () {
    test("у OpenBible два раздела, и различает их первая буква ключа", () {
      // Ошибка здесь тиха: ссылка откроется и приведёт в чужую запись.
      expect(placeExternalUrl("openbible", "a1234"),
          "https://www.openbible.info/geo/ancient/a1234");
      expect(placeExternalUrl("openbible", "m5678"),
          "https://www.openbible.info/geo/modern/m5678");
    });

    test("викиданные и Pleiades ведут к себе", () {
      expect(placeExternalUrl("wikidata", "Q1218"), contains("wikidata.org/wiki/Q1218"));
      expect(placeExternalUrl("pleiades", "687928"), contains("pleiades.stoa.org/places/687928"));
    });

    test("у статьи Никифора внешнего адреса нет — она наша", () {
      expect(placeExternalUrl("nikifor", "nikifor-ierusalim"), isNull);
      expect(placeExternalUrl("editor", "x"), isNull);
      expect(placeExternalUrl("wikidata", ""), isNull);
    });
  });

  test("точка открывается в чужой карте, а не схемой geo:", () {
    // geo: понимает только Android, и на iOS такая ссылка кончается отказом.
    final url = placeMapUrl(31.7683, 35.2137);

    expect(url, startsWith("https://www.openstreetmap.org/"));
    expect(url, contains("mlat=31.7683"));
    expect(url, contains("mlon=35.2137"));
  });
}
