import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/dto/prayer_text.dart';

// Разбор ответа личной ручки `/api/v2/prayer-text`: tolerant, как у ордо —
// незнакомые поля и мусор проходят мимо, а не падают.

void main() {
  group("NamedPrayer", () {
    test("полный разбор", () {
      final prayer = NamedPrayer.fromJson(const <String, dynamic>{
        "id": "dep-1",
        "title": "Молитва об усопших",
        "text": "Господи, упокой души усопших раб Твоих…",
      });
      expect(prayer.id, "dep-1");
      expect(prayer.title, "Молитва об усопших");
      expect(prayer.text, contains("Господи"));
    });

    test("tolerant: мусор в полях пустеет, а не падает", () {
      final prayer = NamedPrayer.fromJson(const <String, dynamic>{
        "id": 7,
        "title": null,
        "text": 42,
        "extra": "не наше",
      });
      expect(prayer.id, "");
      expect(prayer.title, isNull);
      expect(prayer.text, "");
    });

    test("toJson без title не пишет title", () {
      final json = const NamedPrayer(id: "a", text: "x").toJson();
      expect(json.containsKey("title"), isFalse);
      expect(json["id"], "a");
      expect(json["text"], "x");
    });

    test("toJson/fromJson круговой", () {
      const original = NamedPrayer(id: "a", title: "t", text: "x");
      final restored = NamedPrayer.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.text, original.text);
    });
  });

  group("PrayerText", () {
    test("полный ответ ручки", () {
      final parsed = PrayerText.fromJson(const <String, dynamic>{
        "for": "departed",
        "style": "molitvoslov-short",
        "lang": "cu",
        "gender": "f",
        "prayers": <Map<String, dynamic>>[
          <String, dynamic>{"id": "p1", "text": "А"},
          <String, dynamic>{"id": "p2", "title": "Б", "text": "В"},
        ],
      });
      expect(parsed.forKind, "departed");
      expect(parsed.style, "molitvoslov-short");
      expect(parsed.lang, "cu");
      expect(parsed.gender, "f");
      expect(parsed.prayers.length, 2);
      expect(parsed.prayers[0].title, isNull);
      expect(parsed.prayers[1].title, "Б");
    });

    test("tolerant: prayers не список → пусто, не исключение", () {
      final parsed = PrayerText.fromJson(const <String, dynamic>{
        "for": 1,
        "prayers": "нет",
      });
      expect(parsed.forKind, "");
      expect(parsed.prayers, isEmpty);
    });

    test("tolerant: элементы-мусор пропускаются", () {
      final parsed = PrayerText.fromJson(const <String, dynamic>{
        "prayers": <dynamic>[
          "строка",
          null,
          <String, dynamic>{"id": "p", "text": "текст"},
          5,
        ],
      });
      expect(parsed.prayers.length, 1);
      expect(parsed.prayers.single.id, "p");
    });
  });
}
