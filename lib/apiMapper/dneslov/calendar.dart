import 'dart:convert';

import 'package:typikon/api/dneslov/calendar.dart';
import 'package:typikon/dto/dneslov/calendar.dart';
import 'package:typikon/dto/dneslov/calendarMeta.dart';

Future<CalendarDayD> getCalendarDayD(String dateTime) async {
  final calendarResponse = await fetchCalendaries();

  final calendarMeta = CalendarMeta.fromJson(jsonDecode(calendarResponse.body));

  final calendarString = calendarMeta.list.fold("", (previousValue, element) => previousValue + element.slug + ",");

  final response = await fetchCalendarDay(dateTime, calendarString);

  if (response.statusCode == 200) {
    return CalendarDayD.fromJson(jsonDecode(response.body), calendarMeta, calendarString);
  } else {
    throw Exception('Failed to load album');
  }
}