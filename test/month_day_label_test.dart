import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:typikon/pages/month_page.dart';

// Подпись дня в месяцеслове: «1 января» вместо серверного «01.01». Живое
// приложение инициализирует данные локалей делегатами flutter_localizations
// (см. main.dart); у безвиджетного теста виджетов нет — данные просим у intl
// напрямую.
void main() {
  setUpAll(() async {
    await initializeDateFormatting("ru");
  });

  test("январь: первый день подписывается «1 января»", () {
    expect(monthDayLabel("01.01", 1, 1, "ru"), "1 января");
  });

  test("29 февраля легально в условном високосном году", () {
    expect(monthDayLabel("29.02", 2, 29, "ru"), "29 февраля");
  });

  test("последний день декабря", () {
    expect(monthDayLabel("31.12", 12, 31, "ru"), "31 декабря");
  });

  test("имя не вида «dd.MM» показывается как есть", () {
    expect(monthDayLabel("Неделя мытаря и фарисея", 1, 15, "ru"),
        "Неделя мытаря и фарисея");
  });

  test("имя вида «dd.MM» не оправдывает нелегального месяца", () {
    // Месяц берётся из monthIndex ответа, а не из имени: «01.01» с
    // monthIndex 13 — враньё сервера, подписывать его «1 января» нечестно.
    expect(monthDayLabel("01.01", 13, 1, "ru"), "01.01");
  });

  test("имя null подписывается пустым", () {
    expect(monthDayLabel(null, 1, 1, "ru"), "");
  });
}
