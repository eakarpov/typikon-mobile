import 'package:shared_preferences/shared_preferences.dart';

/// УВЕДОМЛЕНИЕ О ЧТЕНИЯХ ДНЯ.
///
/// Обычными ключами хранилища, а не полем состояния: их читает фоновая задача, а
/// она живёт в отдельном изоляте, где хранилища состояния нет вовсе. Тот же
/// приём, что у напоминаний помянника.
///
/// **Час выбирает человек.** Восемь утра — не всеобщее время: кто-то читает до
/// работы, кто-то накануне вечером, чтобы успеть на вечерню. Поэтому хранится
/// именно час, а не «включено».
///
/// **Час — местный, и в этом вся тонкость.** Уведомление о чтениях, пришедшее в
/// три ночи, — хуже, чем не пришедшее вовсе; сервер поэтому считает время по
/// поясу устройства, а не по своему.
const String readingHourKey = "dayReadingHour";
const String readingLastNotifiedKey = "dayReadingLastNotified";

/// Час, в который человек просил говорить. `null` — не просил.
Future<int?> dayReadingHour() async {
  final prefs = await SharedPreferences.getInstance();
  final hour = prefs.getInt(readingHourKey);
  // Час вне суток — не «выключено», а испорченная запись; ведём себя как с
  // выключенным, но не притворяемся, что это выбор.
  if (hour == null || hour < 0 || hour > 23) return null;
  return hour;
}

Future<void> setDayReadingHour(int? hour) async {
  final prefs = await SharedPreferences.getInstance();
  if (hour == null) {
    await prefs.remove(readingHourKey);
    return;
  }
  await prefs.setInt(readingHourKey, hour);
}

/// Когда в последний раз говорили. Без этой отметки фоновая задача, просыпаясь
/// несколько раз за час, повторила бы одно и то же.
Future<String?> lastReadingNotice() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(readingLastNotifiedKey);
}

Future<void> rememberReadingNotice(String date) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(readingLastNotifiedKey, date);
}
