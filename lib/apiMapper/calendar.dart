import 'dart:convert';

import '../api/calendar.dart';
import '../dto/calendar.dart';
import '../dto/day_saints.dart';
import 'v2/errors.dart';

Future<CalendarDay> getCalendarDay(String dateTime) async {
  final response = await fetchCalendarDay(dateTime);

  if (response.statusCode == 200) {
    return CalendarDay.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Календарь пока недоступен');
  }
}

/// Святые дня из нашего каталога.
///
/// Считают их сервер: по гражданской дате он сам накладывает тринадцать дней
/// до юлианского календаря. Пустой список — не отказ: связи памятей с
/// каталогом выверены ещё не все, и пустой день здесь — обычное дело.
Future<DaySaints> getDaySaints(String dateTime) async {
  final response = await fetchDaySaints(dateTime);
  if (response.statusCode == 200) {
    return DaySaints.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить святых дня");
}
