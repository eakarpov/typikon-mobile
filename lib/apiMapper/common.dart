import 'dart:convert';

import "../dto/common.dart";
import "../apiMapper/reading.dart";
import "../apiMapper/calendar.dart";

Future<MainPageData> updateData(String dateTime) async {
  final response = await getCalendarDay(dateTime);
  final response2 = await getLastTexts();

  return MainPageData(day: response, lastTexts: response2);
}