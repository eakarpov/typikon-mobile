import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

// Выбор изданий — настройка читателя, и ломается она тихо: человек выбирает
// греческий рядом со славянским, а на следующем заходе видит один славянский и
// решает, что приложение его не запомнило.

Store<AppState> store() => Store<AppState>(appReducer, initialState: AppState.init());

void main() {
  test("по умолчанию выбора нет, и это не «ни одного»", () {
    // Пустой список означает «издание разрешится само»: код издания по умолчанию
    // не зашивается, иначе это была бы шестая копия списка изданий.
    expect(AppState.init().settings.bibleEditions, isEmpty);
  });

  test("выбор запоминается", () {
    final app = store();
    app.dispatch(ChangeBibleEditionsAction(["cs-eliz", "grc-lxx-pat"]));

    expect(app.state.settings.bibleEditions, ["cs-eliz", "grc-lxx-pat"]);
  });

  test("порядок изданий сохраняется как есть", () {
    // Порядок задаёт порядок колонок; переставь его — и на другом заходе тот же
    // набор выглядел бы иначе.
    final app = store();
    app.dispatch(ChangeBibleEditionsAction(["grc-lxx-pat", "cs-eliz"]));

    expect(app.state.settings.bibleEditions, ["grc-lxx-pat", "cs-eliz"]);
  });

  test("сброс цветов чтения выбор изданий не трогает", () {
    // Редьюсер сброса собирает Settings полным конструктором, и пропущенное поле
    // молча вернулось бы к умолчанию — то есть выбор изданий исчез бы от нажатия
    // кнопки, которая к нему отношения не имеет.
    final app = store();
    app.dispatch(ChangeBibleEditionsAction(["cs-eliz", "ro-1688"]));
    app.dispatch(ResetReadingColorsAction());

    expect(app.state.settings.bibleEditions, ["cs-eliz", "ro-1688"]);
  });

  group("сохранение между запусками", () {
    test("выбор переживает запись и чтение", () {
      final settings = const Settings().copyWith(bibleEditions: ["cs-eliz", "la-vulgata"]);
      final restored = Settings.fromJson(settings.toJson());

      expect(restored.bibleEditions, ["cs-eliz", "la-vulgata"]);
    });

    test("состояние прежней версии читается без миграции", () {
      // У тех, кто обновился, ключа в сохранённом состоянии нет вовсе.
      final restored = Settings.fromJson({"fontSize": 18, "themeMode": "dark"});

      expect(restored.bibleEditions, isEmpty);
      expect(restored.fontSize, 18);
    });

    test("мусор вместо списка не роняет чтение настроек", () {
      expect(Settings.fromJson({"bibleEditions": "cs-eliz"}).bibleEditions, isEmpty);
      expect(Settings.fromJson({"bibleEditions": [1, "cs-eliz", null]}).bibleEditions, ["cs-eliz"]);
    });
  });

  test("настройки с разным выбором изданий не считаются равными", () {
    // Иначе стор не заметил бы смены выбора и не перерисовал экран.
    const base = Settings();

    expect(base.copyWith(bibleEditions: ["cs-eliz"]), isNot(base));
    expect(
      base.copyWith(bibleEditions: ["cs-eliz"]),
      base.copyWith(bibleEditions: ["cs-eliz"]),
    );
  });
}
