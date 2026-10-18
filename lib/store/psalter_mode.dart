import 'package:shared_preferences/shared_preferences.dart';

/// Читательские пометки поминального чтения Псалтири.
///
/// Те же ворота, что у `rule_marks.dart` — обычные ключи `SharedPreferences`,
/// мимо Redux: это читательский выбор, а не библиотечный прогресс, и фоновым
/// задачам он не нужен. Ключи намеренно plain.

/// «Имена усопших на славах»: когда включён, кафизмы и «Подряд» открываются
/// в поминальном режиме (с молитвами после каждой славы).
const String psalterDepartedModeKey = "psalter_departed_mode";

/// О ком читается сорокоуст: идентификатор лица из помянника.
const String psalterSorokoustPersonKey = "psalter_sorokoust_person";

Future<bool> psalterDepartedMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(psalterDepartedModeKey) ?? false;
}

Future<void> setPsalterDepartedMode(bool on) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(psalterDepartedModeKey, on);
}

/// Выбранное лицо сорокоуста. `null` — никто не выбран.
Future<String?> psalterSorokoustPerson() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(psalterSorokoustPersonKey);
}

Future<void> setPsalterSorokoustPerson(String? id) async {
  final prefs = await SharedPreferences.getInstance();
  if (id == null || id.isEmpty) {
    await prefs.remove(psalterSorokoustPersonKey);
  } else {
    await prefs.setString(psalterSorokoustPersonKey, id);
  }
}
