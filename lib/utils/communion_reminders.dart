import 'package:shared_preferences/shared_preferences.dart';
import '../store/communion_plan.dart';
import '../store/rule_marks.dart';
import 'rule_reminders.dart';

/// Подготовка напоминается вечером только ДО выбранного дня причащения.
/// Утром дня причащения вечернее напоминание уже неуместно.
RuleReminderNotice communionReminderVerdict({
  required CommunionPlan? plan,
  required bool enabled,
  required String? lastNotifiedDate,
  required DateTime now,
  bool done = false,
}) {
  if (!enabled || plan == null || done) {
    return const RuleReminderNotice.silent('нет активной подготовки');
  }
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(communionPreparationStart(plan.date)) ||
      !today.isBefore(plan.date)) {
    return const RuleReminderNotice.silent('вне дней подготовки');
  }
  final slot = ruleReminderVerdict(
    enabled: true,
    hour: ruleEveningHour,
    lastNotifiedDate: lastNotifiedDate,
    now: now,
  );
  if (!slot.shows) return slot;
  return RuleReminderNotice.show(
    'Время подготовки к Причащению',
    'communion:${dayKey(plan.date)}',
  );
}

Future<void> checkCommunionRemindersAndNotify({
  required Future<void> Function(String body, String payload) show,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  final plan = await getCommunionPlan();
  if (plan != null) await migrateCommunionMarks(dayKey(plan.date));
  final prefix = plan == null ? '' : 'communion_done:${dayKey(plan.date)}:';
  final notice = communionReminderVerdict(
    plan: plan,
    enabled: prefs.getBool(communionReminderKey) ?? false,
    lastNotifiedDate: prefs.getString(communionLastNoticeKey),
    now: at,
    done:
        plan != null &&
        communionPreparationItemIds.every(
          (id) => prefs.getBool('$prefix$id') == true,
        ),
  );
  if (!notice.shows) return;
  await show(notice.body!, notice.payload!);
  await prefs.setString(communionLastNoticeKey, dayKey(at));
}
