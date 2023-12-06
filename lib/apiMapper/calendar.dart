import 'dart:convert';

import '../api/calendar.dart';
import '../dto/calendar.dart';
import "../dto/day.dart";

Future<CalendarDay> getCalendarDay(String dateTime) async {
  final response = await fetchCalendarDay(dateTime);

  if (response.statusCode == 200) {
    return CalendarDay.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Календарь пока недоступен');
  }
}

Future<DayResult> getCalendarReadingForDate(int dateTime) async {
  final response = await fetchCalendarReadingForDate(dateTime);

  if (response.statusCode == 200) {
    return DayResult.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Календарь пока недоступен');
  }
}