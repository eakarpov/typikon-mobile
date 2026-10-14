import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/utils/text_type_labels.dart';

// Подписи типов текстов. Сервер шлёт коды, русские слова знает приложение — и
// всякий незнакомый код должен показаться как есть, а не спрятаться: заведут в
// корпусе новый род текста, и молчание выглядело бы как потеря записи.

void main() {
  group("известные типы", () {
    test("переводятся", () {
      expect(textTypeLabel("Teaching"), "Учительные");
      expect(textTypeLabel("Reference"), "Справочные");
      expect(textTypeLabel("Praising"), "Похвальные");
      expect(textTypeLabel("Historic"), "Исторические");
    });

    test("типы из живого корпуса переводятся", () {
      // Встречены в данных библиотеки сверх четырёх заявленных.
      expect(textTypeLabel("Synaxarion"), "Сказания");
      expect(textTypeLabel("Interpretation"), "Толкования");
      expect(textTypeLabel("Prayer"), "Молитвы");
      expect(textTypeLabel("Catechistic"), "Катехизические");
    });
  });

  test("незнакомый код показывается собой", () {
    expect(textTypeLabel("Hymn"), "Hymn");
  });

  test("регистр различается: тот же код с маленькой буквы — уже незнакомый", () {
    expect(textTypeLabel("teaching"), "teaching");
  });

  test("пустое остаётся пустым, а не становится словом", () {
    expect(textTypeLabel(null), "");
    expect(textTypeLabel(""), "");
  });
}
