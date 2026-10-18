import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store/rule_marks.dart';

/// НАПОМИНАНИЯ О МОЛИТВЕННОМ ПРАВИЛЕ.
///
/// **Часы фиксированные, выбор — «утром / вечером».** У чтений дня человек
/// выбирает час сам (`utils/day_reading_reminders.dart`): кто-то молится до
/// работы, кто-то накануне. Правило устроено проще — два переключателя, и за
/// каждым стоит свой час: утренний 7 и вечерний 21. Это не назначение
/// времени молитвы, а сторож, который напомнит, если день прокрутился.
///
/// **Окно, а не мгновение — как у чтений дня.** Фоновая задача просыпается,
/// когда система даст ей окно, и в минуту не попадает; час назначенный и
/// следующий за ним — то, в чём напоминание ещё уместно.
///
/// **Дважды за вечер не говорим, но утро и вечер — разные слоты.** У каждого
/// своё «сегодня уже говорили»: отдельным ключом, иначе вечернее напоминание
/// сгорело бы вместе с утренним.

/// Час утреннего напоминания.
const int ruleMorningHour = 7;

/// Час вечернего напоминания.
const int ruleEveningHour = 21;

/// Сколько часов после назначенного напоминание ещё уместно.
const int ruleReminderWindowHours = 2;

const String ruleRemindMorningKey = "rule_remind_morning";
const String ruleRemindEveningKey = "rule_remind_evening";
const String ruleRemindMorningLastKey = "rule_remind_last_morning";
const String ruleRemindEveningLastKey = "rule_remind_last_evening";

@immutable
class RuleReminderNotice {
  /// Что показать. `null` — не показывать ничего.
  final String? body;

  /// Куда вести по нажатию.
  final String? payload;

  /// Почему промолчали — для отладки и для теста, наружу не идёт.
  final String? silence;

  const RuleReminderNotice._({this.body, this.payload, this.silence});

  const RuleReminderNotice.silent(String why) : this._(silence: why);

  const RuleReminderNotice.show(String body, String payload)
      : this._(body: body, payload: payload);

  bool get shows => body != null;
}

/// Говорить ли сейчас о правиле — для одного слота (утреннего или вечернего).
///
/// Чистое решение, без диска и без сети: ошибка в этих воротах либо будит
/// человека ночью, либо повторяет одно и то же несколько раз за вечер.
RuleReminderNotice ruleReminderVerdict({
  required bool enabled,
  required int hour,
  required String? lastNotifiedDate,
  required DateTime now,
}) {
  if (!enabled) return const RuleReminderNotice.silent("напоминание выключено");

  final date = dayKey(now);
  if (lastNotifiedDate == date) {
    return const RuleReminderNotice.silent("сегодня уже говорили");
  }

  if (now.hour < hour || now.hour >= hour + ruleReminderWindowHours) {
    return const RuleReminderNotice.silent("не время");
  }

  return const RuleReminderNotice.show("Время молитвенного правила", "rule:");
}

Future<bool> ruleReminderEnabled(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) ?? false;
}

/// Запоминает выбор переключателя. Отметку «сегодня говорили» снимаем всегда:
/// иначе выключивший и тут же включивший напоминание не услышал бы его до
/// завтра — выбор свежий, и ворота «один раз в день» к нему не должны
/// цепляться.
Future<void> setRuleReminder(String key, bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, enabled);
  await prefs.remove(key == ruleRemindMorningKey
      ? ruleRemindMorningLastKey
      : ruleRemindEveningLastKey);
}

/// Сказать о правиле, если пора.
///
/// Показ отделён от решения: решение чистое и проверяется тестами, а здесь —
/// диск и уведомление. Тот же порядок, что у чтений дня и помянника. Сеть
/// здесь не нужна вовсе: правило собирается из того, что уже на устройстве.
Future<void> checkRuleRemindersAndNotify({
  required Future<void> Function(String body, String payload) show,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final date = dayKey(at);
  final prefs = await SharedPreferences.getInstance();

  const slots = <(String, String, int)>[
    (ruleRemindMorningKey, ruleRemindMorningLastKey, ruleMorningHour),
    (ruleRemindEveningKey, ruleRemindEveningLastKey, ruleEveningHour),
  ];

  for (final slot in slots) {
    final verdict = ruleReminderVerdict(
      enabled: prefs.getBool(slot.$1) ?? false,
      hour: slot.$3,
      lastNotifiedDate: prefs.getString(slot.$2),
      now: at,
    );
    if (!verdict.shows) continue;

    await show(verdict.body!, verdict.payload!);
    await prefs.setString(slot.$2, date);
  }
}
