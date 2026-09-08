import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/store/models/settings.dart';

// Настройки читаемости. Хранятся они рядом с прочими и переживают обновление
// приложения — значит проверять надо не «сохраняется ли», а что происходит с
// состоянием, записанным прежней версией, и что «во всю ширину» отличается от
// «не выбирали».

void main() {
  group("состояние прежней версии", () {
    test("получает те же умолчания, что и новое", () {
      // Ключей нет вовсе: тот, кто обновился, не должен получить нулевой
      // интервал и текст, слипшийся в кашу.
      final old = Settings.fromJson({"fontSize": 18, "themeMode": "dark"});

      expect(old.lineHeight, 1.5);
      expect(old.readingAlign, "justify");
      expect(old.readingMeasure, isNull);
      expect(old.fontSize, 18);
    });

    test("целое число интервала не роняет разбор", () {
      // JSON не различает 2 и 2.0: записанное как целое, оно вернётся `int`,
      // и `as double` на нём бросит.
      expect(Settings.fromJson({"lineHeight": 2}).lineHeight, 2.0);
    });

    test("неизвестная выключка считается выключкой по ширине", () {
      expect(Settings.fromJson({"readingAlign": "центр"}).readingAlign, "justify");
    });
  });

  group("ширина колонки", () {
    test("«во всю ширину» — это выбор, а не его отсутствие", () {
      // Обычный copyWith проглотил бы `null` как «не меняем», и вернуть полную
      // ширину после выбора узкой стало бы невозможно.
      const chosen = Settings(readingMeasure: 544.0);

      expect(chosen.copyWith(clearMeasure: true).readingMeasure, isNull);
      expect(chosen.copyWith(fontSize: 20).readingMeasure, 544.0);
    });

    test("переживает запись и чтение", () {
      const settings = Settings(readingMeasure: 736.0, lineHeight: 1.8, readingAlign: "left");
      final back = Settings.fromJson(settings.toJson());

      expect(back.readingMeasure, 736.0);
      expect(back.lineHeight, 1.8);
      expect(back.readingAlign, "left");
    });
  });

  test("равенство различает читаемость", () {
    // Иначе перерисовки не будет: Redux сравнивает состояние, и настройка,
    // выпавшая из `==`, применится только после перезапуска.
    const base = Settings();

    expect(base == base.copyWith(lineHeight: 1.8), isFalse);
    expect(base == base.copyWith(readingAlign: "left"), isFalse);
    expect(base == base.copyWith(readingMeasure: 544.0), isFalse);
  });
}
