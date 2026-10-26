import 'package:shared_preferences/shared_preferences.dart';
import 'rule_marks.dart';

/// Вечер и следующее утро составляют одно правило до 15:00 местного времени.
class RuleCycle {
  static const resetHour = 15;
  final DateTime evening;
  final DateTime morning;
  final DateTime nextReset;

  RuleCycle.at(DateTime now)
    : evening = DateTime(
        now.year,
        now.month,
        now.day - (now.hour < resetHour ? 1 : 0),
      ),
      morning = DateTime(
        now.year,
        now.month,
        now.day + (now.hour < resetHour ? 0 : 1),
      ),
      nextReset = DateTime(
        now.year,
        now.month,
        now.day + (now.hour < resetHour ? 0 : 1),
        resetHour,
      );

  String get key => dayKey(evening);
  String get progressId => 'rule:cycle:$key';
  String get marksPrefix => 'rule_cycle:v1:$key:';
}

const _eveningSections = {'evening_prayerbook', 'compline'};

/// Однократно переносим календарные отметки в соответствующие вечер и утро.
/// Отдельное пространство ключей исключает повторное появление снятых галочек.
Future<Map<String, bool>> ruleCycleMarks(RuleCycle cycle) async {
  final prefs = await SharedPreferences.getInstance();
  final migrated = 'rule_cycle_migrated:v1:${cycle.key}';
  if (prefs.getBool(migrated) != true) {
    for (final date in [cycle.evening, cycle.morning]) {
      final evening = date == cycle.evening;
      final old = await marksWithPrefix('rule_done:${dayKey(date)}:');
      for (final entry in old.entries) {
        if (_eveningSections.contains(entry.key) != evening) continue;
        final key = '${cycle.marksPrefix}${entry.key}';
        if (!prefs.containsKey(key)) await prefs.setBool(key, entry.value);
      }
    }
    await prefs.setBool(migrated, true);
  }
  return marksWithPrefix(cycle.marksPrefix);
}

Future<void> setRuleCycleSectionDone(
  RuleCycle cycle,
  String section,
  bool done,
) async {
  await ruleCycleMarks(cycle);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('${cycle.marksPrefix}$section', done);
}
