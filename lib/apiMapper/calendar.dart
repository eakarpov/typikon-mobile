import 'dart:convert';

import '../api/calendar.dart';
import '../dto/calendar.dart';

Future<CalendarDay> getCalendarDay(String dateTime) async {
  final response = await fetchCalendarDay(dateTime);

  if (response.statusCode == 200) {
    return CalendarDay.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Календарь пока недоступен');
  }
}