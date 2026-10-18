import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/utils/rule_reminders.dart';

// Ворота напоминания о правиле. Ошибка в них либо будит человека ночью, либо
// повторяет одно и то же несколько раз за вечер — заметить можно только на
// себе, и потому проверяется оно здесь.

void main() {
  final atSevenThirty = DateTime(2026, 10, 14, 7, 30);
  final atNineThirty = DateTime(2026, 10, 14, 21, 30);

  test("говорит в назначенный час", () {
    final notice = ruleReminderVerdict(
        enabled: true, hour: 7, lastNotifiedDate: null, now: atSevenThirty);

    expect(notice.shows, isTrue);
    expect(notice.body, "Время молитвенного правила");
    expect(notice.payload, "rule:");
  });

  test("выключенное напоминание молчит", () {
    expect(
        ruleReminderVerdict(
                enabled: false,
                hour: 7,
                lastNotifiedDate: null,
                now: atSevenThirty)
            .shows,
        isFalse);
  });

  test("до часа и после окна — не время", () {
    expect(
        ruleReminderVerdict(
                enabled: true,
                hour: 7,
                lastNotifiedDate: null,
                now: DateTime(2026, 10, 14, 6, 59))
            .shows,
        isFalse);
    // Окно в два часа: в 9:00 напоминание о семи уже невпопад.
    expect(
        ruleReminderVerdict(
                enabled: true,
                hour: 7,
                lastNotifiedDate: null,
                now: DateTime(2026, 10, 14, 9))
            .shows,
        isFalse);
    // Вечерний слот: 21..23.
    expect(
        ruleReminderVerdict(
                enabled: true,
                hour: 21,
                lastNotifiedDate: null,
                now: DateTime(2026, 10, 14, 22, 59))
            .shows,
        isTrue);
    expect(
        ruleReminderVerdict(
                enabled: true,
                hour: 21,
                lastNotifiedDate: null,
                now: DateTime(2026, 10, 14, 23))
            .shows,
        isFalse);
  });

  test("дважды за день не говорит", () {
    expect(
        ruleReminderVerdict(
                enabled: true,
                hour: 21,
                lastNotifiedDate: "2026-10-14",
                now: atNineThirty)
            .shows,
        isFalse);
  });

  group("фоновая проверка", () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test("говорит по включённому слоту и запоминает день", () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{ruleRemindMorningKey: true});
      final shown = <String>[];

      await checkRuleRemindersAndNotify(
        now: atSevenThirty,
        show: (body, payload) async => shown.add(body),
      );

      expect(shown, <String>["Время молитвенного правила"]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ruleRemindMorningLastKey), "2026-10-14");

      // Второй прогон за тот же день молчит.
      await checkRuleRemindersAndNotify(
        now: DateTime(2026, 10, 14, 8),
        show: (body, payload) async => shown.add(body),
      );
      expect(shown, hasLength(1));
    });

    test("утро и вечер — разные слоты: вечером утренняя отметка не мешает",
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ruleRemindMorningKey: true,
        ruleRemindEveningKey: true,
        ruleRemindMorningLastKey: "2026-10-14", // утром уже говорили
      });
      final shown = <String>[];

      await checkRuleRemindersAndNotify(
        now: atNineThirty,
        show: (body, payload) async => shown.add(body),
      );

      expect(shown, <String>["Время молитвенного правила"]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ruleRemindEveningLastKey), "2026-10-14");
    });

    test("ничего не включено — ничего не говорит", () async {
      final shown = <String>[];
      await checkRuleRemindersAndNotify(
        now: atSevenThirty,
        show: (body, payload) async => shown.add(body),
      );
      expect(shown, isEmpty);
    });
  });

  group("переключатель", () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
          ruleRemindMorningLastKey: "2026-10-14",
        }));

    test("включение снимает отметку «сегодня говорили»", () async {
      await setRuleReminder(ruleRemindMorningKey, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ruleRemindMorningKey), isTrue);
      expect(prefs.containsKey(ruleRemindMorningLastKey), isFalse);
      expect(await ruleReminderEnabled(ruleRemindMorningKey), isTrue);
    });

    test("выключение тоже снимает отметку — выбор свежий", () async {
      await setRuleReminder(ruleRemindMorningKey, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ruleRemindMorningKey), isFalse);
      expect(prefs.containsKey(ruleRemindMorningLastKey), isFalse);
    });
  });
}
