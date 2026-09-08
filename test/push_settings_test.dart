import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/store/models/settings.dart';

// Кто будит: приложение или сервер. Настройка, у которой цена ошибки не в том,
// что человек увидит не то, а в том, что он НЕ увидит ничего и не узнает об
// этом: толчок не пришёл — и тишина.

void main() {
  test("умолчание — приложение", () {
    // Толчки требуют разрешения, сети и живого ключа доставки. Включаться сами,
    // без спроса, они не должны.
    expect(const Settings().reminderSource, "device");
    expect(const Settings().remindsFromServer, isFalse);
  });

  test("состояние прежней версии остаётся за приложением", () {
    // Обновившийся не должен молча оказаться на толчках, которых он не просил
    // и для которых не давал разрешения.
    expect(Settings.fromJson({"fontSize": 16}).reminderSource, "device");
  });

  test("неизвестный источник считается приложением", () {
    // Умолчание выбрано так, чтобы ошибка вела к работающему, а не к молчанию.
    expect(Settings.fromJson({"reminderSource": "почтой"}).reminderSource, "device");
  });

  test("выбор переживает запись и чтение", () {
    const settings = Settings(reminderSource: "server");
    final back = Settings.fromJson(settings.toJson());

    expect(back.remindsFromServer, isTrue);
  });

  test("равенство различает источник", () {
    // Иначе экран настроек не перерисуется после выбора.
    const base = Settings();
    expect(base == base.copyWith(reminderSource: "server"), isFalse);
  });

  test("сброс цветов чтения источника не трогает", () {
    // Конструктор в _resetReadingColors полный, и пропущенное поле молча
    // вернулось бы к умолчанию — то есть сброс цветов выключил бы толчки.
    const settings = Settings(reminderSource: "server", lineHeight: 1.8);
    final reset = Settings(
      fontSize: settings.fontSize,
      themeMode: settings.themeMode,
      backgroundColor: null,
      fontColor: null,
      preloadTexts: settings.preloadTexts,
      lineHeight: settings.lineHeight,
      readingAlign: settings.readingAlign,
      readingMeasure: settings.readingMeasure,
      reminderSource: settings.reminderSource,
      bibleEditions: settings.bibleEditions,
    );

    expect(reset.remindsFromServer, isTrue);
    expect(reset.lineHeight, 1.8);
  });
}
