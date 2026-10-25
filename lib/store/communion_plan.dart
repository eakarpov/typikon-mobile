import 'package:shared_preferences/shared_preferences.dart';
import 'rule_marks.dart';

const communionStartKey = 'communion_plan_start';
const communionDateKey = 'communion_plan_date';
const communionReminderKey = 'communion_remind';
const communionLastNoticeKey = 'communion_remind_last';

DateTime? parseCommunionDate(String? value) {
  final date = DateTime.tryParse(value ?? '');
  return date != null && dayKey(date) == value ? date : null;
}

DateTime communionPreparationStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - 3);

const communionPreparationItemIds = [
  'canon:0',
  'canon:1',
  'canon:2',
  'service',
  'prayers',
];

/// Старые повторы сворачиваются в один список; последующее снятие отметки
/// сохраняется, миграция для даты выполняется лишь однажды.
Future<void> migrateCommunionMarks(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final migration = 'communion_fixed_plan:$date';
  if (prefs.getBool(migration) == true) return;
  final prefix = 'communion_done:$date:';
  for (final key in prefs.getKeys().toList()) {
    if (!key.startsWith(prefix) || prefs.getBool(key) != true) continue;
    final match = RegExp(
      r'^evening(\d+):(canon|posledovanie)$',
    ).firstMatch(key.substring(prefix.length));
    if (match == null) continue;
    final targets = match[2] == 'canon'
        ? ['canon:${int.parse(match[1]!) % 3}']
        : ['service', 'prayers'];
    for (final target in targets) {
      if (!prefs.containsKey('$prefix$target')) {
        await prefs.setBool('$prefix$target', true);
      }
    }
  }
  await prefs.setBool(migration, true);
}

class CommunionPlan {
  final DateTime start;
  final DateTime date;
  const CommunionPlan(this.start, this.date);
}

Future<CommunionPlan?> getCommunionPlan() async {
  final prefs = await SharedPreferences.getInstance();
  final start = parseCommunionDate(prefs.getString(communionStartKey));
  final date = parseCommunionDate(prefs.getString(communionDateKey));
  if (start == null || date == null || date.isBefore(start)) return null;
  return CommunionPlan(start, date);
}

Future<void> saveCommunionPlan(CommunionPlan plan) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(communionStartKey, dayKey(plan.start));
  await prefs.setString(communionDateKey, dayKey(plan.date));
  // Новую дату подтверждают отдельно: прежнее согласие относится к прежнему плану.
  await prefs.setBool(communionReminderKey, false);
  await prefs.remove(communionLastNoticeKey);
}

Future<bool> communionReminderEnabled() async =>
    (await SharedPreferences.getInstance()).getBool(communionReminderKey) ??
    false;

Future<void> setCommunionReminder(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(communionReminderKey, enabled);
}
