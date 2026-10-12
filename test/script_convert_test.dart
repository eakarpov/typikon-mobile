import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/components/script_toggle.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/models/settings.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/utils/script_convert.dart';

// Письмо: уставом или гражданкой. Строки — из самого собрания: канон на
// Обрезание (корпус `cu_gr`) и Ин. 1 по Елизаветинской Библии.

void main() {
  group("из гражданки в устав", () {
    test("придыхание и буквы начала слова", () {
      expect(toChurch("я́же"), "ꙗ҆́же");
      expect(toChurch("еги́петския"), "є҆ги́петскія");
      expect(toChurch("уче́ние"), "ᲂу҆че́ніе");
      expect(toChurch("Уте́шителю"), "Оу҆те́шителю");
      expect(toChurch("и"), "и҆");
    });

    test("«і» перед гласной", () {
      expect(toChurch("Иису́се"), "І҆ису́се");
      expect(toChurch("Мари́я"), "Марі́я");
    });

    test("ер после конечной согласной", () {
      expect(toChurch("грех"), "грехъ");
      expect(toChurch("в нас"), "въ насъ");
      expect(toChurch("дней"), "дней", reason: "после «й» ер не пишется");
    });

    test("предлоги своими буквами", () {
      expect(toChurch("от сердца́"), "ѿ сердца́");
      expect(toChurch("о нас"), "ѡ҆ насъ");
    });

    test("вария на конечном слоге — только перед следующим словом", () {
      expect(toChurch("Христу́ Бо́гу,"), "Христу̀ Бо́гу,");
      expect(toChurch("всади́/ в сердца́"), "всади́/ въ сердца́",
          reason: "косая черта — конец строки песнопения");
      expect(toChurch("Тебе́."), "Тебе́.");
    });

    test("ятей, омег и титл правило не выдумывает", () {
      expect(toChurch("вера"), "вера");
      expect(toChurch("Бог"), "Богъ");
    });
  });

  group("из устава в гражданку", () {
    test("буквы и знаки", () {
      expect(toCivil("Въ нача́лѣ бѣ̀ сло́во"), "В нача́ле бе́ сло́во");
      expect(toCivil("и҆ сло́во бѣ̀ ѿ"), "и сло́во бе́ от");
      expect(toCivil("Ѳео́дѡръ, Ѱало́мъ, ѯе́нїѧ"), "Фео́дор, Псало́м, ксе́ния");
      expect(toCivil("ᲂу҆чи́телѣ"), "учи́теле");
    });

    test("ижица: «в» после «а» и «е», иначе «и»", () {
      expect(toCivil("Є҆ѵа̀"), "Ева́");
      expect(toCivil("сѷнѡдъ"), "синод");
    });

    test("«оу» внутри слова — не «у»", () {
      expect(toCivil("поꙋча́ти"), "поуча́ти");
    });

    test("слово под титлом остаётся книжным", () {
      expect(toCivil("ѿ бг҃а, и҆ бг҃ъ"), "от бг҃а, и бг҃ъ");
      expect(toCivil("Є҆ѵⷢ҇лїе"), "Є҆ѵⷢ҇лїе");
    });

    test("разметка не переводится", () {
      expect(
        toCivil("{k|Сла́ва,} і҆ ны́нѣ{12}: {pl|ierusalim|Іерꙋсали́мъ}"),
        "{k|Сла́ва,} и ны́не{12}: {pl|ierusalim|Иерусали́м}",
      );
    });

    test("латиница и цифры не трогаются", () {
      expect(toCivil("Psalm 1:1"), "Psalm 1:1");
      expect(toChurch("Psalm 1:1"), "Psalm 1:1");
    });
  });

  group("что и куда переводится", () {
    test("только тексты другого письма", () {
      expect(convertsScript(TextScript.church, scriptCivil), isTrue);
      expect(convertsScript(TextScript.civil, scriptChurch), isTrue);
      expect(convertsScript(TextScript.church, scriptChurch), isFalse);
      expect(convertsScript(TextScript.civil, scriptCivil), isFalse);
      expect(convertsScript(TextScript.church, scriptAsSource), isFalse);
      // Русскую прозу уставом не переписываем ни при какой настройке.
      expect(convertsScript(TextScript.other, scriptChurch), isFalse);
      expect(presentScript("вера", TextScript.other, scriptChurch), "вера");
    });

    test("шрифт под письмо", () {
      expect(presentFont("OldStandard", TextScript.civil, scriptChurch), "Monomakh",
          reason: "в OldStandard нет узкого «ᲂ»");
      expect(presentFont("Monomakh", TextScript.church, scriptCivil), "OldStandard");
      expect(presentFont("Monomakh", TextScript.church, scriptAsSource), "Monomakh");
    });

    test("издания Библии: уставом только cu", () {
      expect(bibleScript("cu"), TextScript.church);
      expect(bibleScript("ro_cyr"), TextScript.other, reason: "румынский кириллицей");
      expect(chantScript("cu_gr"), TextScript.civil);
      expect(chantScript(null), TextScript.civil, reason: "у акафистов языка нет, они cu_gr");
      expect(chantScript("grc"), TextScript.other);
    });
  });

  group("настройка", () {
    test("переживает сохранение, а прежнее состояние читается «как набрано»", () {
      final saved = const Settings(script: "civil").toJson();
      expect(Settings.fromJson(saved).script, "civil");
      expect(Settings.fromJson({"themeMode": "system"}).script, "source");
      expect(Settings.fromJson({"themeMode": "system", "script": "мусор"}).script, "source");
    });

    testWidgets("кнопка в шапке переключает общую настройку", (tester) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      var changed = 0;
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [
              ScriptToggle(source: TextScript.civil, onChanged: () => changed++),
            ]),
          ),
        ),
      ));

      await tester.tap(find.byTooltip("Уставом"));
      expect(store.state.settings.script, scriptChurch);
      expect(changed, 1);
    });

    testWidgets("у текста не на церковнославянском кнопки нет", (tester) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [
              ScriptToggle(source: TextScript.other, onChanged: () {}),
            ]),
          ),
        ),
      ));

      expect(find.byType(IconButton), findsNothing);
    });
  });
}
