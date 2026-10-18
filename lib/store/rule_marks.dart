import 'package:shared_preferences/shared_preferences.dart';

/// Отметки молитвенных правил: галочки «прочитано» и род молящегося.
///
/// Обычными ключами хранилища, а не полем состояния: те же ворота, что у
/// напоминаний помянника и чтений дня — фоновая задача живёт в изоляции без
/// хранилища состояния, и читать её настройки может только отсюда.
///
/// Ключи намеренно plain: `rule_done:<дата>:<секция>`, `communion_done:<дата>:<пункт>`
/// и `rule_gender`. Это читательские пометки, а не библиотечный прогресс: фон
/// их не читает (и это нормально), и копиться им негде — секций дня пять,
/// дата в ключе стирает вчерашнее сама.

const String ruleGenderKey = "rule_gender";
const String _ruleDonePrefix = "rule_done:";
const String _communionDonePrefix = "communion_done:";

/// Дата одним ключом: «2026-10-14». Тот же вид ждёт ручка календаря.
String dayKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, "0");
  return "${date.year.toString().padLeft(4, "0")}-${two(date.month)}-${two(date.day)}";
}

const List<String> _monthsGenitive = <String>[
  "", "января", "февраля", "марта", "апреля", "мая", "июня",
  "июля", "августа", "сентября", "октября", "ноября", "декабря",
];

/// Дата для человека: «14 октября 2026». Имена месяцев — родительный падеж,
/// как в книжных датах.
String dayLabel(DateTime date) =>
    "${date.day} ${_monthsGenitive[date.month]} ${date.year}";

/// Все отметки с данным префиксом — без повторных обращений за каждым ключом.
/// Возвращает карту «хвост ключа после префикса → отметка».
Future<Map<String, bool>> marksWithPrefix(String prefix) async {
  final prefs = await SharedPreferences.getInstance();
  final found = <String, bool>{};
  for (final key in prefs.getKeys()) {
    if (key.startsWith(prefix)) {
      found[key.substring(prefix.length)] = prefs.getBool(key) ?? false;
    }
  }
  return found;
}

Future<bool> isRuleSectionDone(String date, String sectionId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool("$_ruleDonePrefix$date:$sectionId") ?? false;
}

Future<void> setRuleSectionDone(String date, String sectionId, bool done) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool("$_ruleDonePrefix$date:$sectionId", done);
}

/// Род молящегося: «m» или «f». Влияет на текст последований (молитвы на сон
/// и ко Причащению спрашивают мужской или женский род) и подпись в отчёте для
/// хозяина устройства. Испорченная запись читается как «m» — умолчание
/// приложения для этого человека.
Future<String> ruleGender() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(ruleGenderKey) == "f" ? "f" : "m";
}

Future<void> setRuleGender(String gender) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(ruleGenderKey, gender == "f" ? "f" : "m");
}

Future<bool> isCommunionItemDone(String date, String itemId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool("$_communionDonePrefix$date:$itemId") ?? false;
}

Future<void> setCommunionItemDone(String date, String itemId, bool done) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool("$_communionDonePrefix$date:$itemId", done);
}
