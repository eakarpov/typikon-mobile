import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  Store<AppState> store() => Store<AppState>(appReducer, initialState: AppState.init());

  group("состояние по умолчанию", () {
    test("предзагрузка выключена, пока пользователь не ответил", () {
      final settings = store().state.settings;

      expect(settings.isPreloadEnabled, isFalse);
      expect(settings.shouldAskAboutPreload, isTrue);
      expect(settings.preloadTexts, isNull);
    });
  });

  group("ответ пользователя", () {
    test("«скачивать» включает предзагрузку", () {
      final s = store();
      s.dispatch(ChangePreloadTextsAction(true));

      expect(s.state.settings.isPreloadEnabled, isTrue);
      expect(s.state.settings.shouldAskAboutPreload, isFalse);
    });

    test("«не нужно» — не то же самое, что «не спрашивали»", () {
      // Иначе предложение всплывало бы при каждом запуске.
      final s = store();
      s.dispatch(ChangePreloadTextsAction(false));

      expect(s.state.settings.isPreloadEnabled, isFalse);
      expect(s.state.settings.shouldAskAboutPreload, isFalse);
    });

    test("переключение не задевает остальные настройки", () {
      final s = store();
      s.dispatch(ChangeFontSizeAction(22));
      s.dispatch(ChangeThemeModeAction(ThemeMode.dark));
      s.dispatch(ChangePreloadTextsAction(true));

      expect(s.state.settings.fontSize, 22);
      expect(s.state.settings.themeMode, ThemeMode.dark);
    });
  });

  group("сохранение между запусками", () {
    test("все три состояния переживают запись и чтение", () {
      for (final value in <bool?>[null, true, false]) {
        final restored = Settings.fromJson(Settings(preloadTexts: value).toJson());

        expect(restored.preloadTexts, value, reason: "значение $value");
      }
    });

    test("состояние прежних версий читается как «не спрашивали»", () {
      // У обновившихся ключа в сохранённом состоянии нет — предзагрузка не
      // должна включиться сама, им положено предложение.
      final restored = Settings.fromJson({
        "fontSize": 16,
        "themeMode": "system",
        "backgroundColor": null,
        "fontColor": null,
      });

      expect(restored.preloadTexts, isNull);
      expect(restored.shouldAskAboutPreload, isTrue);
    });

    test("мусор вместо значения не сходит за согласие", () {
      final restored = Settings.fromJson({"themeMode": "system", "preloadTexts": "да"});

      expect(restored.isPreloadEnabled, isFalse);
    });
  });

  test("сброс цветов чтения не отменяет ответ про предзагрузку", () {
    final s = store();
    s.dispatch(ChangePreloadTextsAction(true));
    s.dispatch(ResetReadingColorsAction());

    expect(s.state.settings.isPreloadEnabled, isTrue);
  });
}
