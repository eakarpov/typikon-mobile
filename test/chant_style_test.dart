import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/utils/chant_style.dart';

// Шрифт песнопения. Ошибка здесь не роняет ничего и не видна в коде: текст
// показан, буквы читаются — просто не те, какими он набран. Приложение так и
// рисовало гражданский церковнославянский уставным шрифтом, потому что коды
// корпуса (`cu_gr`) похожи на коды Библии (`cu`), а значат разное.

void main() {
  test("cu_gr — гражданка, и рисуется гражданским шрифтом", () {
    // Проверено по корпусу: во всех 123 227 строках cu_gr нет ни титла, ни
    // звательца, ни узкого ᲂ — только гражданская кириллица с ударениями.
    expect(chantFontFamily("cu_gr"), "OldStandard");
  });

  test("уставное начертание получает уставный шрифт", () {
    expect(chantFontFamily("cu"), "Monomakh");
    expect(chantFontFamily("ro_cyr"), "Monomakh");
  });

  test("прочие языки корпуса — гражданским", () {
    for (final code in ["ro", "grc", "en", "et", "ar"]) {
      expect(chantFontFamily(code), "OldStandard", reason: code);
    }
  });

  test("незнакомое начертание не получает уставный шрифт", () {
    // Ошибиться в эту сторону дешевле: латиница уставным шрифтом читается хуже,
    // чем церковнославянский гражданским.
    expect(chantFontFamily("he"), "OldStandard");
    expect(chantFontFamily(null), "OldStandard");
    expect(chantFontFamily(""), "OldStandard");
  });
}
